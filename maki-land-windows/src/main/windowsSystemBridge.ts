import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
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
Add-Type -AssemblyName System.Windows.Forms
$ps = [System.Windows.Forms.SystemInformation]::PowerStatus
$batPct = [int][Math]::Round($ps.BatteryLifePercent * 100)
if ($batPct -lt 0 -or $batPct -gt 100) { $batPct = 100 }
$hasBat = ($ps.BatteryChargeStatus -band [System.Windows.Forms.BatteryChargeStatus]::NoSystemBattery) -eq 0
$charging = ($ps.PowerLineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online)

$title = ''
$artist = ''
$app = ''
$playing = $false

try {
  [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime] | Out-Null
  $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation\`1' })[0]
  function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(1200) | Out-Null
    return $netTask.Result
  }
  $mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
  if ($mgr -ne $null) {
    $session = $mgr.GetCurrentSession()
    if ($session -ne $null) {
      $pb = $session.GetPlaybackInfo()
      if ($pb -ne $null) {
        $playing = ($pb.PlaybackStatus -eq [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionPlaybackStatus]::Playing)
      }
      $props = Await ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
      if ($props -ne $null) {
        $title = [string]$props.Title
        $artist = [string]$props.Artist
      }
      $rawApp = [string]$session.SourceAppUserModelId
      if ($rawApp -match 'Spotify') { $app = 'Spotify' }
      elseif ($rawApp -match 'chrome') { $app = 'Chrome' }
      elseif ($rawApp -match 'msedge') { $app = 'Edge' }
      elseif ($rawApp -match 'AppleMusic|iTunes') { $app = 'Apple Music' }
      elseif ($rawApp -match 'vlc') { $app = 'VLC' }
      else { $app = ($rawApp -replace '\\.exe$','') }
    }
  }
} catch {}

$fgName = ''
try {
  if (-not ("Win32Fg" -as [type])) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32Fg {
      [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
      [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    }
"@
  }
  $hwnd = [Win32Fg]::GetForegroundWindow()
  $pidOut = [uint32]0
  [Win32Fg]::GetWindowThreadProcessId($hwnd, [ref]$pidOut) | Out-Null
  if ($pidOut -gt 0) {
    $fgName = (Get-Process -Id $pidOut).ProcessName
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
    const out = await runPowerShell(WINDOWS_STATUS_PS, 3200);
    if (out) {
      const parsed = JSON.parse(out);
      cachedBattery = {
        level: typeof parsed.batPct === 'number' ? parsed.batPct : 100,
        isCharging: Boolean(parsed.charging),
        hasBattery: parsed.hasBat !== false,
      };
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
  if (cmd === 'playPause') {
    cachedTrack.isPlaying = !cachedTrack.isPlaying;
  }
  setTimeout(() => {
    void pollWindowsStatusOnce();
  }, 450);
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
    const escaped = normalized.replace(/'/g, "''");
    const isImage = /\.(png|jpe?g|bmp|gif|webp)$/i.test(normalized);
    // Win32 CF_HDROP clipboard format via PowerShell 5.1 / 7 compatible .NET Forms API
    // SetDataObject($data, $true) ensures the clipboard content persists after the PowerShell process exits
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
    await runPowerShell(ps, 3000);
    return true;
  } catch (err) {
    console.error('[copyFileToWindowsClipboard] Error:', err);
    return false;
  }
}
