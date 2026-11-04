import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { clipboard } from 'electron';
import { SystemMetrics, TrackInfo } from '../shared/types';

const isWin = process.platform === 'win32';

interface CpuTimesSnapshot {
  idle: number;
  total: number;
}

function readCpuSnapshot(): CpuTimesSnapshot {
  const cpus = os.cpus();
  let idle = 0;
  let total = 0;
  for (const cpu of cpus) {
    idle += cpu.times.idle;
    total += cpu.times.user + cpu.times.nice + cpu.times.sys + cpu.times.irq + cpu.times.idle;
  }
  return { idle, total };
}

let prevCpu: CpuTimesSnapshot = readCpuSnapshot();
let cachedCpuPercent = 8;
let cachedBattery = { level: 100, isCharging: true, hasBattery: true };
let lastLiveBatteryTimestamp = 0;

export function updateCachedBattery(battery: { level: number; isCharging: boolean; hasBattery: boolean }) {
  cachedBattery = {
    level: Math.max(0, Math.min(100, Math.round(battery.level))),
    isCharging: Boolean(battery.isCharging),
    hasBattery: Boolean(battery.hasBattery),
  };
  lastLiveBatteryTimestamp = Date.now();
}
let cachedTrack: TrackInfo = {
  title: '',
  artist: '',
  appName: '',
  isPlaying: false,
};
let cachedFrontApp = '';
let psPollingBusy = false;

function runPowerShell(script: string, timeoutMs = 3500): Promise<string> {
  if (!isWin) return Promise.resolve('');
  return new Promise((resolve) => {
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Sta', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-Command', script],
      { timeout: timeoutMs, windowsHide: true },
      (err, stdout) => {
        if (err) {
          resolve('');
          return;
        }
        resolve((stdout || '').trim());
      }
    );
  });
}

// Single lightweight combined PowerShell probe for Windows 10/11 Battery + SMTC Media + Foreground App
const WINDOWS_STATUS_PS = `
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue

$batPct = 100
$hasBat = $false
$charging = $true

# 1. Primary: Modern WinRT Windows.Devices.Power (Windows 10/11 - zero lag, realtime mW)
try {
  [Windows.Devices.Power.Battery, Windows.Devices.Power, ContentType = WindowsRuntime] | Out-Null
  $bReport = [Windows.Devices.Power.Battery]::AggregateBattery.GetReport()
  if ($bReport -and $bReport.FullChargeCapacityInMilliwattHours -gt 0) {
    $batPct = [int][Math]::Round(($bReport.RemainingCapacityInMilliwattHours / $bReport.FullChargeCapacityInMilliwattHours) * 100)
    if ($batPct -lt 0) { $batPct = 0 }
    elseif ($batPct -gt 100) { $batPct = 100 }
    $hasBat = $true
    # Status: 1 = NotPresent, 2 = Discharging, 3 = Idle, 4 = Charging
    $st = [int]$bReport.Status
    $charging = ($st -eq 3 -or $st -eq 4)
  }
} catch {}

# 2. Secondary Fallback: Win32_Battery (Direct ACPI EC Query via CIM)
if (-not $hasBat) {
  try {
    $cim = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cim -and $cim.EstimatedChargeRemaining) {
      $batPct = [int]$cim.EstimatedChargeRemaining
      if ($batPct -lt 0) { $batPct = 0 }
      elseif ($batPct -gt 100) { $batPct = 100 }
      $hasBat = $true
      $charging = ($cim.BatteryStatus -ne 1 -and $cim.BatteryStatus -ne 2)
    }
  } catch {}
}

# 3. Tertiary Fallback: System.Windows.Forms SystemInformation
if (-not $hasBat) {
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $ps = [System.Windows.Forms.SystemInformation]::PowerStatus
    if ($ps) {
      $hasBat = ($ps.BatteryChargeStatus -band [System.Windows.Forms.BatteryChargeStatus]::NoSystemBattery) -eq 0
      if ($hasBat) {
        $pVal = [int][Math]::Round($ps.BatteryLifePercent * 100)
        if ($pVal -ge 0 -and $pVal -le 100) {
          $batPct = $pVal
        }
        $charging = ($ps.PowerLineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online)
      }
    }
  } catch {}
}

$title = ''
$artist = ''
$app = ''
$playing = $false

# 1. Primary: Windows 10/11 System Media Transport Controls (WinRT SMTC)
try {
  [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime] | Out-Null
  $mgr = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync().GetAwaiter().GetResult()
  if ($mgr) {
    $session = $mgr.GetCurrentSession()
    if (-not $session) {
      $all = $mgr.GetSessions()
      if ($all) {
        foreach ($s in $all) {
          $pb = $s.GetPlaybackInfo()
          if ($pb -and $pb.PlaybackStatus -eq 4) {
            $session = $s
            break
          }
        }
        if (-not $session -and $all.Count -gt 0) {
          $session = $all[0]
        }
      }
    }

    if ($session) {
      $pb = $session.GetPlaybackInfo()
      if ($pb) {
        # 4 = Playing, 5 = Paused
        $playing = ($pb.PlaybackStatus -eq 4)
      }
      $props = $session.TryGetMediaPropertiesAsync().GetAwaiter().GetResult()
      if ($props) {
        if ($props.Title) { $title = [string]$props.Title }
        if ($props.Artist) { $artist = [string]$props.Artist }
      }
      $rawApp = [string]$session.SourceAppUserModelId
      if ($rawApp -match 'Spotify') { $app = 'Spotify' }
      elseif ($rawApp -match 'chrome') { $app = 'Chrome' }
      elseif ($rawApp -match 'msedge') { $app = 'Edge' }
      elseif ($rawApp -match 'firefox') { $app = 'Firefox' }
      elseif ($rawApp -match 'AppleMusic|iTunes') { $app = 'Apple Music' }
      elseif ($rawApp -match 'vlc') { $app = 'VLC' }
      elseif ($rawApp) { $app = ($rawApp -replace '\\.exe$','') }
    }
  }
} catch {}

# 2. Resilient Fallback: Inspect Process Window Titles (for Spotify Desktop & Web YouTube/Media)
if (-not $title) {
  try {
    # Check Spotify Desktop Window Title ("Artist - Song Title")
    $spot = Get-Process -Name Spotify -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
    if ($spot -and $spot.MainWindowTitle -and $spot.MainWindowTitle -ne 'Spotify' -and $spot.MainWindowTitle -ne 'Spotify Free' -and $spot.MainWindowTitle -ne 'Spotify Premium') {
      $spotTitle = $spot.MainWindowTitle
      $dashIdx = $spotTitle.IndexOf(' - ')
      if ($dashIdx -gt 0) {
        $artist = $spotTitle.Substring(0, $dashIdx).Trim()
        $title = $spotTitle.Substring($dashIdx + 3).Trim()
      } else {
        $title = $spotTitle
      }
      $app = 'Spotify'
      $playing = $true
    }

    # Check Chrome, Edge, Firefox, Brave, Opera for YouTube / Media playback
    if (-not $title) {
      $browsers = Get-Process -Name chrome, msedge, firefox, brave, opera -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match ' - YouTube' } | Select-Object -First 1
      if ($browsers) {
        $bTitle = $browsers.MainWindowTitle
        $bTitle = $bTitle -replace ' - YouTube Music.*$', ''
        $bTitle = $bTitle -replace ' - YouTube.*$', ''
        $bTitle = $bTitle -replace ' - Google Chrome.*$', ''
        $bTitle = $bTitle -replace ' - Microsoft Edge.*$', ''
        $bTitle = $bTitle -replace ' - Mozilla Firefox.*$', ''
        $bTitle = $bTitle -replace ' - Brave.*$', ''
        $bTitle = $bTitle -replace ' - Opera.*$', ''
        $dashIdx = $bTitle.IndexOf(' - ')
        if ($dashIdx -gt 0) {
          $artist = $bTitle.Substring(0, $dashIdx).Trim()
          $title = $bTitle.Substring($dashIdx + 3).Trim()
        } else {
          $title = $bTitle.Trim()
        }
        $app = 'YouTube'
        $playing = $true
      }
    }
  } catch {}
}

# Lightweight Foreground Process detection WITHOUT dynamic C# compiler overhead
$fgName = ''
try {
  $activeProc = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } | Select-Object -First 1
  if ($activeProc) {
    $fgName = $activeProc.ProcessName
  }
} catch {}

@{
  batPct = $batPct
  hasBat = $hasBat
  charging = $charging
  title = $title
  artist = $artist
  app = $app
  playing = $playing
  fg = $fgName
} | ConvertTo-Json -Compress
`;

export async function pollWindowsStatusOnce(): Promise<void> {
  // Always update cross-platform CPU %
  const cur = readCpuSnapshot();
  const dTotal = cur.total - prevCpu.total;
  const dIdle = cur.idle - prevCpu.idle;
  prevCpu = cur;
  if (dTotal > 0) {
    cachedCpuPercent = Math.max(1, Math.min(100, Math.round(((dTotal - dIdle) / dTotal) * 100)));
  }

  if (!isWin || psPollingBusy) return;
  psPollingBusy = true;
  try {
    const out = await runPowerShell(WINDOWS_STATUS_PS, 2800);
    if (out) {
      const parsed = JSON.parse(out);
      const isRecentLive = Date.now() - lastLiveBatteryTimestamp < 15000;
      
      // Update battery cache: prioritize live Chromium battery API if reported recently
      if (!isRecentLive || !cachedBattery.hasBattery) {
        cachedBattery = {
          level: typeof parsed.batPct === 'number' ? parsed.batPct : 100,
          isCharging: Boolean(parsed.charging),
          hasBattery: parsed.hasBat !== false,
        };
      }
      cachedTrack = {
        title: String(parsed.title || ''),
        artist: String(parsed.artist || ''),
        appName: String(parsed.app || ''),
        isPlaying: Boolean(parsed.playing),
      };
      cachedFrontApp = String(parsed.fg || '').toLowerCase();
    }
  } catch {
    // Ignore transient JSON/PS errors
  } finally {
    psPollingBusy = false;
  }
}

export function getSystemMetricsSnapshot(): SystemMetrics {
  const totalBytes = os.totalmem();
  const freeBytes = os.freemem();
  const usedBytes = Math.max(0, totalBytes - freeBytes);
  const ramTotalGB = Math.round((totalBytes / (1024 ** 3)) * 10) / 10;
  const ramUsedGB = Math.round((usedBytes / (1024 ** 3)) * 10) / 10;
  const ramPercent = totalBytes > 0 ? Math.round((usedBytes / totalBytes) * 100) : 0;

  return {
    cpuPercent: cachedCpuPercent,
    ramUsedGB,
    ramTotalGB,
    ramPercent,
    batteryLevel: cachedBattery.level,
    isCharging: cachedBattery.isCharging,
    hasBattery: cachedBattery.hasBattery,
  };
}

export function getCurrentTrackSnapshot(): TrackInfo {
  return { ...cachedTrack };
}

export function getFrontAppName(): string {
  return cachedFrontApp;
}

export async function sendWindowsMediaControl(cmd: 'playPause' | 'next' | 'prev'): Promise<void> {
  if (!isWin) {
    if (cmd === 'playPause') {
      cachedTrack.isPlaying = !cachedTrack.isPlaying;
      if (cachedTrack.isPlaying && !cachedTrack.title) {
        cachedTrack.title = 'Lofi Capybara Beats';
        cachedTrack.artist = 'Maki Studio';
        cachedTrack.appName = 'Spotify';
      }
    }
    return;
  }

  if (cmd === 'playPause') {
    cachedTrack.isPlaying = !cachedTrack.isPlaying;
  }

  // Virtual-Key codes: 0xB3 = VK_MEDIA_PLAY_PAUSE, 0xB0 = VK_MEDIA_NEXT_TRACK, 0xB1 = VK_MEDIA_PREV_TRACK
  const vk = cmd === 'playPause' ? 0xb3 : cmd === 'next' ? 0xb0 : 0xb1;
  const ps = `
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MediaKeySender {
  [DllImport("user32.dll")]
  public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@ -ErrorAction SilentlyContinue
[MediaKeySender]::keybd_event(${vk}, 0, 0, [UIntPtr]::Zero)
[MediaKeySender]::keybd_event(${vk}, 0, 2, [UIntPtr]::Zero)
`;
  await runPowerShell(ps, 2000);

  setTimeout(() => {
    void pollWindowsStatusOnce();
  }, 250);
  setTimeout(() => {
    void pollWindowsStatusOnce();
  }, 750);
}

export async function toggleWindowsMicMute(nextMuted: boolean): Promise<boolean> {
  if (!isWin) return nextMuted;
  // APPCOMMAND_MICROPHONE_VOLUME_MUTE = 24 (24 << 16 = 1572864)
  const ps = `
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MicCmd {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
"@ -ErrorAction SilentlyContinue
$h = [MicCmd]::GetForegroundWindow()
[MicCmd]::SendMessageW($h, 0x0319, $h, [IntPtr]1572864) | Out-Null
`;
  await runPowerShell(ps, 2000);
  return nextMuted;
}

export async function copyFileToWindowsClipboard(filePath: string): Promise<boolean> {
  if (!isWin) return false;
  try {
    const normalized = path.win32 ? path.win32.normalize(path.resolve(filePath)) : path.resolve(filePath);
    if (!fs.existsSync(normalized)) return false;

    // 1. Instant native Win32 CF_HDROP clipboard write via Electron buffer (0ms latency)
    // Allows immediate Ctrl+V paste into Windows Explorer, Desktop, folders, and messaging apps
    try {
      const dropFilesHeader = Buffer.alloc(20);
      dropFilesHeader.writeUInt32LE(20, 0); // pFiles offset (20 bytes)
      dropFilesHeader.writeUInt32LE(0, 4);  // pt.x = 0
      dropFilesHeader.writeUInt32LE(0, 8);  // pt.y = 0
      dropFilesHeader.writeUInt32LE(0, 12); // fNC = 0
      dropFilesHeader.writeUInt32LE(1, 16); // fWide = 1 (Unicode UTF-16LE)

      // Double null-terminated UTF-16LE file path string
      const filePathBuffer = Buffer.from(normalized + '\0\0', 'utf16le');
      const hDrop = Buffer.concat([dropFilesHeader, filePathBuffer]);
      clipboard.writeBuffer('CF_HDROP', hDrop);
    } catch (clipErr) {
      console.warn('[copyFileToWindowsClipboard] Native CF_HDROP write failed:', clipErr);
    }

    // 2. Also register image / file drop list via background PowerShell (non-blocking)
    const escaped = normalized.replace(/'/g, "''");
    const isImage = /\.(png|jpe?g|bmp|gif|webp)$/i.test(normalized);
    const ps = `
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$data = New-Object System.Windows.Forms.DataObject
$col = New-Object System.Collections.Specialized.StringCollection
$col.Add('${escaped}')
$data.SetFileDropList($col)
if ('${isImage ? 'true' : 'false'}' -eq 'true') {
  try {
    $img = [System.Drawing.Image]::FromFile('${escaped}')
    $data.SetImage($img)
  } catch {}
}
[System.Windows.Forms.Clipboard]::SetDataObject($data, $true)
`;
    void runPowerShell(ps, 3000).catch(() => {});
    return true;
  } catch (err) {
    console.error('[copyFileToWindowsClipboard] Error:', err);
    return false;
  }
}
