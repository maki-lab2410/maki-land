import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import {
  app,
  BrowserWindow,
  clipboard,
  dialog,
  ipcMain,
  Menu,
  nativeImage,
  powerMonitor,
  screen,
  session,
  shell,
  Tray,
} from 'electron';
import {
  ALL_ISLAND_TABS,
  CalendarEventItem,
  CAPY_FOODS,
  CapyActionType,
  CapyFood,
  CapyMascotModel,
  ClipboardEntry,
  computeTargetIslandSize,
  DESKTOP_CHAT_HEIGHT,
  DESKTOP_CHAT_WIDTH,
  DESKTOP_NORMAL_HEIGHT,
  DESKTOP_NORMAL_WIDTH,
  ISLAND_CANVAS_HEIGHT,
  ISLAND_CANVAS_WIDTH,
  isIdleShowActivity,
  IslandTab,
  LauncherItem,
  MakiGeminiModel,
  SharedAppState,
  TodoItem,
} from '../shared/types';
import {
  getCurrentTrackSnapshot,
  getFrontAppName,
  getSystemMetricsSnapshot,
  pollWindowsStatusOnce,
  sendWindowsMediaControl,
  toggleWindowsMicMute,
  copyFileToWindowsClipboard,
} from './windowsSystemBridge';
import { StudioService } from './studioService';
import { GeminiManager } from './geminiService';
import { WindowsCacheCleanerService } from './cacheCleanerService';

// --- Single-Instance Lock (Prevents Duplicate Windows on Boot / Double-Click) ---
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
  process.exit(0);
}

interface PersistedData {
  isLaunchAtLogin: boolean;
  mood: number;
  fullness: number;
  xp: number;
  orangesOnHead: number;
  isOnsenMode: boolean;
  mascotModel: CapyMascotModel;
  showInCompactNotch: boolean;
  isOnDesktop: boolean;
  desktopRoamEnabled: boolean;
  desktopOrigin: { x: number; y: number } | null;
  scratchpadText: string;
  todos: TodoItem[];
  launcherItems: LauncherItem[];
  localCalendarEvents: CalendarEventItem[];
  googleICSUrl: string;
}

const PET_QUOTES = [
  'adem dielus..',
  'hehe makasih ya',
  'hmm nyaman banget',
  'jadi ngantuk nih..',
  'santai aja kerjanya',
  'jangan lupa minum air ya',
];
const TICKLISH_QUOTES = ['eh geli tau..', 'haha jangan disitu', 'pelan-pelan dong..'];
const DIZZY_QUOTES = ['aduh pusing..', 'jangan ditoel terus dong', 'muter-muter nih kepalaku..'];

class MakiMainController {
  private islandWin: BrowserWindow | null = null;
  private desktopWin: BrowserWindow | null = null;
  private tray: Tray | null = null;

  private studio: StudioService;
  private gemini: GeminiManager;
  private cleaner = WindowsCacheCleanerService.getInstance();

  // Core UI & Companion state
  private isIslandVisible = true;
  private isExpanded = false;
  private isShowingOnboarding = false;
  private hasCompletedOnboarding = false;
  private updateAvailable: {
    version: string;
    url: string;
    notes: string;
    downloadUrl?: string;
    isDownloading?: boolean;
    downloadPercent?: number;
  } | null = null;
  private isCompactHovering = false;
  private selectedTab: IslandTab = 'maki-land';
  private isPinned = false;
  private isModalOpen = false;
  private isMirrorOpen = false;
  private isLaunchAtLogin = true;
  private isMicMuted = false;
  private collapseCooldownUntil = 0;

  private mood = 90;
  private fullness = 85;
  private xp = 15;
  private orangesOnHead = 1;
  private isOnsenMode = false;
  private mascotModel: CapyMascotModel = 'classic';
  private showInCompactNotch = true;
  private isOnDesktop = false;
  private desktopRoamEnabled = true;
  private isDraggingOnDesktop = false;
  private isChasingCursor = false;
  private isMouthOpenForDrop = false;
  private desktopPointerInside = false;
  private isReturningToNotch = false;
  private notchClimbProgress = 0;
  private currentAction: CapyActionType = 'chill';
  private eatingEmoji = '🍊';
  private lookVector = { x: 0, y: 0 };
  private lastSquishTime = 0;
  private speechBubble: string | null = null;
  private contextualTip: string | null = null;
  private desktopBubble: string | null = null;
  private heartBurstSeq = 0;
  private posX = 0;
  private facingRight = false;
  private desktopOrigin = { x: 0, y: 0 };

  // Companion Moko (Multi-Monitor)
  private companionWin: BrowserWindow | null = null;
  private companionOrigin = { x: 0, y: 0 };
  private companionBubble: string | null = null;
  private companionBubbleTimer: ReturnType<typeof setTimeout> | null = null;
  private companionAction: string = 'chill';
  private companionFacingRight = false;
  private companionOranges = 1;
  private companionIsOnsen = false;
  private companionRoamEnabled = true;
  private companionWalkTimer: ReturnType<typeof setInterval> | null = null;
  private companionWalkTarget: { x: number; y: number } | null = null;
  private banterIndex = 0;
  private banterTimer: ReturnType<typeof setInterval> | null = null;
  private readonly banterPairs = [
    { maki: 'Moko, monitor sebelah adem ya?', moko: 'Iya Maki, adem dan lega banget di sini! ✨' },
    { maki: 'Semangat ya nemenin bos kerja! 💻', moko: 'Pasti! Jangan lupa istirahat mata ya! 👀' },
    { maki: 'Moko, jangan ketiduran ya!', moko: 'Gak kok, aku cuma merem merem ayam hehe 💤' },
    { maki: 'Enaknya nanti kita berendam onsen bareng ya ♨️', moko: 'Setuju! Air hangat sama jeruk rebus mantap!' },
    { maki: 'Layar kamu ada file apa aja tuh?', moko: 'Banyak kerjaan beres, bos kita rajin banget! 👍' },
  ];

  // Calendar, Notes, Launcher, Clipboard, Timer
  private localCalendarEvents: CalendarEventItem[] = [];
  private icsCalendarEvents: CalendarEventItem[] = [];
  private googleICSUrl = '';
  private isSyncingICS = false;
  private calendarError: string | null = null;
  private isShowingCalendarSettings = false;

  private scratchpadText = '';
  private todos: TodoItem[] = [
    { id: crypto.randomUUID(), title: 'Fokus kerja / belajar', isDone: false },
    { id: crypto.randomUUID(), title: 'Minum air putih', isDone: true },
  ];
  private notesToast: string | null = null;

  private launcherItems: LauncherItem[] = [];
  private clipboardHistory: ClipboardEntry[] = [];
  private lastClipText = '';
  private lastClipImgHash = '';

  private timerTotal = 0;
  private timerRemaining = 0;
  private timerRunning = false;
  private timerAlert = false;

  // Motion & Interaction internals
  private pokeStreak = 0;
  private lastPokeTime = 0;
  private lastStrokeSoundTime = 0;
  private lastActivityIndex = -1;
  private dropHoldUntil = 0;

  private walkTarget: { x: number; y: number } | null = null;
  private homePhase:
    | { kind: 'none' }
    | { kind: 'doorstep'; doorstepX: number; doorstepY: number; insideY: number }
    | { kind: 'climbing'; doorstepX: number; doorstepY: number; insideY: number; progress: number } =
    { kind: 'none' };
  private throwVel = { x: 0, y: 0 };
  private dragStartMouse = { x: 0, y: 0 };
  private dragStartOrigin = { x: 0, y: 0 };
  private lastDragMouse = { x: 0, y: 0 };
  private lastDragTime = 0;
  private dragVelocity = { x: 0, y: 0 };
  private isWindowDragActive = false;
  private isNativeFileDragging = false;

  private islandIgnoreMouse: boolean | null = null;
  private desktopIgnoreMouse: boolean | null = null;

  private actionResetTimeout: NodeJS.Timeout | null = null;
  private bubbleTimeout: NodeJS.Timeout | null = null;
  private tipTimeout: NodeJS.Timeout | null = null;
  private deskBubbleTimeout: NodeJS.Timeout | null = null;
  private chaseStopTimeout: NodeJS.Timeout | null = null;
  private toastTimeout: NodeJS.Timeout | null = null;
  private broadcastScheduled = false;

  constructor() {
    this.studio = new StudioService(() => this.scheduleBroadcast());
    this.gemini = new GeminiManager(
      this.studio,
      () => this.buildStateSnapshot(),
      () => {
        this.syncDesktopWindowSizeForChat();
        this.scheduleBroadcast();
      }
    );
    this.cleaner.setOnChange(() => this.scheduleBroadcast());
    this.loadPersisted();

    if (!this.hasCompletedOnboarding) {
      setTimeout(() => {
        this.isExpanded = true;
        this.isShowingOnboarding = true;
        this.scheduleBroadcast();
      }, 1200);
    }
  }

  private get stateFilePath(): string {
    return path.join(app.getPath('userData'), 'maki_state.json');
  }

  private getAssetPath(name: string): string {
    const devPath = path.resolve(__dirname, '../../assets', name);
    if (fs.existsSync(devPath) && !devPath.includes('.asar')) return devPath;
    const resPath = path.join(process.resourcesPath, 'assets', name);
    if (fs.existsSync(resPath) && !resPath.includes('.asar')) return resPath;
    const cachedPath = path.join(app.getPath('userData'), 'assets', name);
    if (fs.existsSync(cachedPath)) return cachedPath;
    try {
      if (fs.existsSync(devPath)) {
        fs.mkdirSync(path.dirname(cachedPath), { recursive: true });
        fs.writeFileSync(cachedPath, fs.readFileSync(devPath));
        return cachedPath;
      }
    } catch {}
    return devPath;
  }

  private defaultLauncherItems(): LauncherItem[] {
    const home = os.homedir();
    if (process.platform === 'win32') {
      return [
        { id: crypto.randomUUID(), name: 'Explorer', urlOrPath: home, iconEmoji: '📁', isWeb: false },
        { id: crypto.randomUUID(), name: 'Downloads', urlOrPath: path.join(home, 'Downloads'), iconEmoji: '⬇️', isWeb: false },
        { id: crypto.randomUUID(), name: 'Screenshots', urlOrPath: path.join(home, 'Pictures', 'Screenshots'), iconEmoji: '📸', isWeb: false },
        { id: crypto.randomUUID(), name: 'Terminal', urlOrPath: 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe', iconEmoji: '💻', isWeb: false },
        { id: crypto.randomUUID(), name: 'ChatGPT', urlOrPath: 'https://chatgpt.com', iconEmoji: '✨', isWeb: true },
        { id: crypto.randomUUID(), name: 'GitHub', urlOrPath: 'https://github.com', iconEmoji: '🐙', isWeb: true },
        { id: crypto.randomUUID(), name: 'YouTube', urlOrPath: 'https://youtube.com', iconEmoji: '▶️', isWeb: true },
      ];
    }
    return [
      { id: crypto.randomUUID(), name: 'Home', urlOrPath: home, iconEmoji: '📁', isWeb: false },
      { id: crypto.randomUUID(), name: 'Downloads', urlOrPath: path.join(home, 'Downloads'), iconEmoji: '⬇️', isWeb: false },
      { id: crypto.randomUUID(), name: 'ChatGPT', urlOrPath: 'https://chatgpt.com', iconEmoji: '✨', isWeb: true },
      { id: crypto.randomUUID(), name: 'GitHub', urlOrPath: 'https://github.com', iconEmoji: '🐙', isWeb: true },
      { id: crypto.randomUUID(), name: 'YouTube', urlOrPath: 'https://youtube.com', iconEmoji: '▶️', isWeb: true },
    ];
  }

  private builtInHolidays(): CalendarEventItem[] {
    const y = new Date().getFullYear();
    return [
      { id: 'hol-ny', title: 'Tahun Baru Masehi', dateISO: `${y}-01-01`, timeLabel: 'Seharian', isAllDay: true, source: 'Holiday', colorHex: '#ff6b6b' },
      { id: 'hol-ri', title: 'HUT Kemerdekaan RI', dateISO: `${y}-08-17`, timeLabel: 'Seharian', isAllDay: true, source: 'Holiday', colorHex: '#ff4757' },
      { id: 'hol-xmas', title: 'Hari Raya Natal', dateISO: `${y}-12-25`, timeLabel: 'Seharian', isAllDay: true, source: 'Holiday', colorHex: '#2ed573' },
    ];
  }

  private loadPersisted() {
    this.launcherItems = this.defaultLauncherItems();
    try {
      if (fs.existsSync(this.stateFilePath)) {
        const d = JSON.parse(fs.readFileSync(this.stateFilePath, 'utf8')) as Partial<PersistedData>;
        if (typeof d.isLaunchAtLogin === 'boolean') this.isLaunchAtLogin = d.isLaunchAtLogin;
        if (typeof d.mood === 'number') this.mood = d.mood;
        if (typeof d.fullness === 'number') this.fullness = d.fullness;
        if (typeof d.xp === 'number') this.xp = d.xp;
        if (typeof d.orangesOnHead === 'number') this.orangesOnHead = d.orangesOnHead;
        if (typeof d.isOnsenMode === 'boolean') this.isOnsenMode = d.isOnsenMode;
        if (d.mascotModel === 'classic' || d.mascotModel === 'plushie') this.mascotModel = d.mascotModel;
        if (typeof d.showInCompactNotch === 'boolean') this.showInCompactNotch = d.showInCompactNotch;
        if (typeof d.isOnDesktop === 'boolean') this.isOnDesktop = d.isOnDesktop;
        if (typeof d.desktopRoamEnabled === 'boolean') this.desktopRoamEnabled = d.desktopRoamEnabled;
        if (d.desktopOrigin && typeof d.desktopOrigin.x === 'number') {
          this.desktopOrigin = d.desktopOrigin;
        }
        if (typeof d.scratchpadText === 'string') this.scratchpadText = d.scratchpadText;
        if (Array.isArray(d.todos)) this.todos = d.todos;
        if (Array.isArray(d.launcherItems) && d.launcherItems.length > 0) {
          this.launcherItems = d.launcherItems;
        }
        if (Array.isArray(d.localCalendarEvents)) this.localCalendarEvents = d.localCalendarEvents;
        if (typeof d.googleICSUrl === 'string') this.googleICSUrl = d.googleICSUrl;
        if (typeof (d as any).hasCompletedOnboarding === 'boolean') {
          this.hasCompletedOnboarding = (d as any).hasCompletedOnboarding;
        }
      }
    } catch {
      // ignore corrupted file
    }
  }

  private savePersisted() {
    try {
      const payload: PersistedData = {
        isLaunchAtLogin: this.isLaunchAtLogin,
        mood: this.mood,
        fullness: this.fullness,
        xp: this.xp,
        orangesOnHead: this.orangesOnHead,
        isOnsenMode: this.isOnsenMode,
        mascotModel: this.mascotModel,
        showInCompactNotch: this.showInCompactNotch,
        isOnDesktop: this.isOnDesktop,
        desktopRoamEnabled: this.desktopRoamEnabled,
        desktopOrigin: this.desktopOrigin,
        scratchpadText: this.scratchpadText,
        todos: this.todos,
        launcherItems: this.launcherItems,
        localCalendarEvents: this.localCalendarEvents,
        googleICSUrl: this.googleICSUrl,
      };
      (payload as any).hasCompletedOnboarding = this.hasCompletedOnboarding;
      fs.writeFileSync(this.stateFilePath, JSON.stringify(payload, null, 2));
    } catch {
      // ignore
    }
  }

  public async init() {
    // Default Desktop Origin near bottom-right above Windows Taskbar if unset
    const primary = screen.getPrimaryDisplay();
    if (this.desktopOrigin.x === 0 && this.desktopOrigin.y === 0) {
      this.desktopOrigin = {
        x: primary.workArea.x + primary.workArea.width - DESKTOP_NORMAL_WIDTH - 28,
        y: primary.workArea.y + primary.workArea.height - DESKTOP_NORMAL_HEIGHT - 12,
      };
    }

    this.applyAutoLaunchSetting(this.isLaunchAtLogin);
    await this.hydrateLauncherIcons();
    if (this.googleICSUrl) {
      void this.syncGoogleICS(this.googleICSUrl);
    }

    // Grant microphone and audio recording permissions for voice recorder feature
    try {
      session.defaultSession.setPermissionRequestHandler((_webContents, permission, callback) => {
        if (permission === 'media') {
          callback(true);
          return;
        }
        callback(false);
      });
      session.defaultSession.setPermissionCheckHandler((_webContents, permission) => {
        if (permission === 'media') {
          return true;
        }
        return false;
      });
    } catch (err) {
      console.warn('[Session Permissions] Warning configuring media permissions:', err);
    }

    this.createIslandWindow();
    this.repositionIslandWindow();
    if (this.isOnDesktop) {
      this.showDesktopWindow(this.desktopOrigin);
    }
    this.setupTray();
    this.setupPowerAndLockScreenListeners();
    this.setupIPC();
    this.startBackgroundLoops();

    app.on('second-instance', () => {
      this.isIslandVisible = true;
      this.islandWin?.show();
      this.setExpanded(true);
    });

    screen.on('display-metrics-changed', () => {
      this.repositionIslandWindow();
      this.syncCompanionWithScreens();
    });

    screen.on('display-added', () => {
      this.repositionIslandWindow();
      setTimeout(() => this.syncCompanionWithScreens(), 800);
    });

    screen.on('display-removed', () => {
      this.repositionIslandWindow();
      this.syncCompanionWithScreens();
    });

    // Check for GitHub Releases
    setTimeout(() => {
      void this.checkForGitHubUpdates(false);
    }, 4500);
    setInterval(() => {
      void this.checkForGitHubUpdates(false);
    }, 1000 * 60 * 60 * 4);
  }

  // --- Autorun at Windows Boot (`HKCU\...\Run` via Electron LoginItemSettings) ---
  private applyAutoLaunchSetting(enabled: boolean) {
    this.isLaunchAtLogin = enabled;
    this.savePersisted();
    if (app.isPackaged) {
      try {
        app.setLoginItemSettings({
          openAtLogin: enabled,
          path: process.execPath,
        });
      } catch {
        // ignore in restricted environments
      }
    }
    this.rebuildTrayMenu();
    this.scheduleBroadcast();
  }

  // --- GitHub Releases Auto-Update Checker ---
  private async checkForGitHubUpdates(manual = false) {
    try {
      const res = await fetch('https://api.github.com/repos/maki-lab2410/maki-land/releases/latest', {
        headers: {
          'User-Agent': 'maki-land-windows',
          Accept: 'application/vnd.github.v3+json',
        },
      });

      if (!res.ok) {
        if (manual) {
          dialog.showMessageBoxSync({
            type: 'info',
            title: 'maki-land Update',
            message: 'Belum ada rilis baru yang ditemukan di GitHub (atau repository masih diset Private).',
          });
        }
        return;
      }

      const data = (await res.json()) as any;
      const latestTag = String(data.tag_name || '').replace(/^v/, '').trim();
      const currentVer = app.getVersion() || '1.0.0';
      if (!latestTag) return;

      const [lMaj, lMin, lPat] = latestTag.split('.').map((n) => parseInt(n, 10) || 0);
      const [cMaj, cMin, cPat] = currentVer.split('.').map((n) => parseInt(n, 10) || 0);

      const isNewer =
        lMaj > cMaj ||
        (lMaj === cMaj && lMin > cMin) ||
        (lMaj === cMaj && lMin === cMin && lPat > cPat);

      let installerDownloadUrl: string | null = null;
      if (Array.isArray(data.assets)) {
        for (const a of data.assets) {
          const name = String(a.name || '').toLowerCase();
          if (name.endsWith('.exe')) {
            installerDownloadUrl = a.browser_download_url;
            if (name.includes('setup')) break;
          }
        }
      }

      if (isNewer) {
        const releaseUrl = data.html_url || 'https://github.com/maki-lab2410/maki-land/releases';
        this.updateAvailable = {
          version: latestTag,
          url: releaseUrl,
          notes: data.body || '',
          downloadUrl: installerDownloadUrl || undefined,
          isDownloading: false,
          downloadPercent: 0,
        };
        this.scheduleBroadcast();

        if (manual) {
          const choice = dialog.showMessageBoxSync({
            type: 'question',
            buttons: ['✨ Perbarui Otomatis (1-Klik)', 'Buka di Browser', 'Nanti Saja'],
            defaultId: 0,
            title: 'Update Tersedia! 🎉',
            message: `Versi baru maki-land (v${latestTag}) sudah tersedia!\n\nVersi kamu saat ini: v${currentVer}\n\nIngin memperbarui secara otomatis sekarang?`,
          });
          if (choice === 0) {
            void this.downloadAndApplyWindowsUpdate(installerDownloadUrl || releaseUrl);
          } else if (choice === 1) {
            void shell.openExternal(releaseUrl);
          }
        } else {
          if (this.isOnDesktop) {
            this.showDesktopBubble(`🎉 Ada versi baru v${latestTag}! Cek di notch atau tray buat update ya~ 🐾`, 6000);
          }
          this.studio.showBanner(`Versi baru maki-land v${latestTag} sudah rilis! Klik tombol Update untuk perbarui otomatis.`, false);
        }
      } else if (manual) {
        dialog.showMessageBoxSync({
          type: 'info',
          title: 'maki-land Update',
          message: `Kamu sudah menggunakan versi terbaru maki-land (v${currentVer})! 🐾`,
        });
      }
    } catch {
      if (manual) {
        dialog.showMessageBoxSync({
          type: 'warning',
          title: 'maki-land Update',
          message: 'Gagal mengecek pembaruan. Pastikan komputer terhubung ke internet.',
        });
      }
    }
  }

  private async downloadAndApplyWindowsUpdate(url: string) {
    const cleanUrl = url.split('?')[0].toLowerCase();
    if (!cleanUrl.endsWith('.exe')) {
      void shell.openExternal(url);
      return;
    }

    if (this.updateAvailable) {
      this.updateAvailable.isDownloading = true;
      this.updateAvailable.downloadPercent = 0;
      this.scheduleBroadcast();
    }
    this.showDesktopBubble('Maki sedang mengunduh pembaruan... ⏳', 25000);
    this.studio.showBanner(`Mengunduh pembaruan v${this.updateAvailable?.version || ''}...`, false, 25000);

    const tempInstaller = path.join(app.getPath('temp'), `makiland_setup_${Date.now()}.exe`);
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Accept: 'application/octet-stream, */*',
        },
        redirect: 'follow',
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);

      const contentLengthHeader = res.headers.get('content-length');
      const totalBytes = contentLengthHeader ? parseInt(contentLengthHeader, 10) : 0;

      const fileStream = fs.createWriteStream(tempInstaller);
      let receivedBytes = 0;
      let lastPercent = 0;
      let lastBroadcastTime = 0;

      if (res.body) {
        const reader = res.body.getReader();
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          if (value) {
            fileStream.write(Buffer.from(value));
            receivedBytes += value.length;
            if (totalBytes > 0) {
              const pct = Math.min(99, Math.round((receivedBytes / totalBytes) * 100));
              const now = Date.now();
              if (pct !== lastPercent && now - lastBroadcastTime > 250) {
                lastPercent = pct;
                lastBroadcastTime = now;
                if (this.updateAvailable) {
                  this.updateAvailable.downloadPercent = pct;
                  this.scheduleBroadcast();
                }
              }
            }
          }
        }
        await new Promise<void>((resolve, reject) => {
          fileStream.end((err?: Error | null) => {
            if (err) reject(err);
            else resolve();
          });
        });
      } else {
        const buffer = Buffer.from(await res.arrayBuffer());
        fs.writeFileSync(tempInstaller, buffer);
      }

      if (this.updateAvailable) {
        this.updateAvailable.downloadPercent = 100;
        this.updateAvailable.isDownloading = false;
        this.scheduleBroadcast();
      }

      this.showDesktopBubble('Memasang pembaruan & memulai ulang... ✨', 5000);
      this.studio.showBanner('Pembaruan selesai diunduh! Memasang & memulai ulang...', false, 5000);

      // Execute installer with /S (silent) and --force-run so NSIS safely waits for file extraction and relaunches via user shell
      const child = spawn(tempInstaller, ['/S', '--force-run'], { detached: true, stdio: 'ignore' });
      child.unref();

      setTimeout(() => {
        app.quit();
      }, 1000);
    } catch (e: any) {
      if (this.updateAvailable) {
        this.updateAvailable.isDownloading = false;
        this.updateAvailable.downloadPercent = 0;
        this.scheduleBroadcast();
      }
      dialog.showErrorBox(
        'Gagal Memperbarui',
        `Gagal mengunduh pembaruan otomatis: ${e?.message || e}\nSilakan unduh manual dari GitHub.`
      );
      void shell.openExternal(url);
    }
  }

  // --- Windows Lock Screen (`Win+L`) & Sleep/Wake Reactions ---
  private setupPowerAndLockScreenListeners() {
    const onLock = () => {
      this.walkTarget = null;
      this.isChasingCursor = false;
      if (this.gemini.isDesktopChatOpen) {
        this.gemini.isDesktopChatOpen = false;
        this.syncDesktopWindowSizeForChat();
      }
      if (this.actionResetTimeout) clearTimeout(this.actionResetTimeout);
      this.currentAction = 'sleeping';
      this.speechBubble = 'zZz.. 🌙';
      this.desktopBubble = 'zZz.. 🌙';
      this.scheduleBroadcast();
    };

    const onUnlock = () => {
      if (this.actionResetTimeout) clearTimeout(this.actionResetTimeout);
      this.currentAction = 'stretching';
      this.registerSquish();
      const greet = 'Selamat datang kembali! 👋✨';
      this.showBubble(greet, 4500);
      this.showDesktopBubble(greet, 4500);
      this.scheduleActionReset(4500);
      this.scheduleBroadcast();
    };

    powerMonitor.on('lock-screen', onLock);
    powerMonitor.on('suspend', onLock);
    powerMonitor.on('unlock-screen', onUnlock);
    powerMonitor.on('resume', onUnlock);
  }

  // --- Windows Creation & Click-Through Management ---
  private preloadPath(): string {
    return path.join(__dirname, 'preload.js');
  }

  private loadWindowPage(win: BrowserWindow, page: 'island.html' | 'desktop.html') {
    const devUrl = process.env.VITE_DEV_SERVER_URL;
    if (devUrl) {
      void win.loadURL(`${devUrl}/${page}`);
    } else {
      const htmlPath = path.resolve(__dirname, '../../dist', page);
      void win.loadFile(htmlPath);
    }
  }

  private createIslandWindow() {
    const primary = screen.getPrimaryDisplay();
    const x = Math.round(primary.bounds.x + (primary.bounds.width - ISLAND_CANVAS_WIDTH) / 2);
    const y = primary.bounds.y;

    const win = new BrowserWindow({
      x,
      y,
      width: ISLAND_CANVAS_WIDTH,
      height: ISLAND_CANVAS_HEIGHT,
      frame: false,
      transparent: true,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      skipTaskbar: true,
      hasShadow: false,
      alwaysOnTop: true,
      show: true,
      backgroundColor: '#00000000',
      icon: this.getAssetPath('icon.ico'),
      webPreferences: {
        preload: this.preloadPath(),
        contextIsolation: true,
        nodeIntegration: false,
      },
    });

    win.setAlwaysOnTop(true, 'screen-saver');
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
    win.setIgnoreMouseEvents(true, { forward: true });
    this.islandIgnoreMouse = true;

    // Log renderer console directly so any issue is visible in terminal/logs
    win.webContents.on('console-message', (_e, level, message, line, sourceId) => {
      console.log(`[Island Renderer] (${level}) ${message} [${sourceId}:${line}]`);
    });

    // Auto-minimize immediately when user clicks outside expanded Island on Windows 10/11
    win.on('blur', () => {
      if (this.isNativeFileDragging) return;
      if (this.isExpanded && !this.isPinned && !this.isModalOpen) {
        const cursor = screen.getCursorScreenPoint();
        if (!this.isPointInsideActiveNotch(cursor)) {
          this.setExpanded(false);
        }
      }
    });

    win.webContents.on('did-finish-load', () => {
      if (this.isIslandVisible && !win.isDestroyed()) {
        win.show();
        win.showInactive();
        win.setAlwaysOnTop(true, 'screen-saver');
        win.moveTop();
      }
    });

    win.webContents.on('render-process-gone', (_e, details) => {
      console.warn('[Maki] island renderer gone:', details.reason);
      if (!win.isDestroyed()) {
        this.loadWindowPage(win, 'island.html');
      }
    });

    this.loadWindowPage(win, 'island.html');
    this.islandWin = win;
  }

  private repositionIslandWindow() {
    if (!this.islandWin || this.islandWin.isDestroyed()) return;
    const primary = screen.getPrimaryDisplay();
    const x = Math.round(primary.bounds.x + (primary.bounds.width - ISLAND_CANVAS_WIDTH) / 2);
    const y = primary.bounds.y;
    this.islandWin.setBounds({
      x,
      y,
      width: ISLAND_CANVAS_WIDTH,
      height: ISLAND_CANVAS_HEIGHT,
    });
  }

  private showDesktopWindow(origin: { x: number; y: number }) {
    const w = this.gemini.isDesktopChatOpen ? DESKTOP_CHAT_WIDTH : DESKTOP_NORMAL_WIDTH;
    const h = this.gemini.isDesktopChatOpen ? DESKTOP_CHAT_HEIGHT : DESKTOP_NORMAL_HEIGHT;
    const currentDisplay = screen.getDisplayNearestPoint(origin);
    const wa = currentDisplay.workArea;
    const clampedX = Math.max(wa.x + 4, Math.min(wa.x + wa.width - w - 4, Math.round(origin.x)));
    const clampedY = Math.max(wa.y + 4, Math.min(wa.y + wa.height - h - 4, Math.round(origin.y)));
    this.desktopOrigin = { x: clampedX, y: clampedY };

    if (!this.desktopWin || this.desktopWin.isDestroyed()) {
      const win = new BrowserWindow({
        x: clampedX,
        y: clampedY,
        width: w,
        height: h,
        frame: false,
        transparent: true,
        resizable: false,
        minimizable: false,
        maximizable: false,
        fullscreenable: false,
        skipTaskbar: true,
        hasShadow: false,
        alwaysOnTop: true,
        backgroundColor: '#00000000',
        icon: this.getAssetPath('icon.ico'),
        webPreferences: {
          preload: this.preloadPath(),
          contextIsolation: true,
          nodeIntegration: false,
        },
      });
      win.setAlwaysOnTop(true, 'screen-saver');
      win.moveTop();
      win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
      win.setIgnoreMouseEvents(true, { forward: true });
      this.desktopIgnoreMouse = true;
      this.loadWindowPage(win, 'desktop.html');
      this.desktopWin = win;
    } else {
      this.desktopWin.setBounds({ x: clampedX, y: clampedY, width: w, height: h });
      this.desktopWin.showInactive();
      this.desktopWin.setAlwaysOnTop(true, 'screen-saver');
      this.desktopWin.moveTop();
    }
  }

  private hideDesktopWindow() {
    if (this.desktopWin && !this.desktopWin.isDestroyed()) {
      this.desktopWin.hide();
    }
  }

  // ── Companion (Moko) window management ────────────────────────────────
  private showCompanionWindow(origin: { x: number; y: number }) {
    const w = DESKTOP_NORMAL_WIDTH;
    const h = DESKTOP_NORMAL_HEIGHT;
    const display = screen.getDisplayNearestPoint(origin);
    const wa = display.workArea;
    const cx = Math.max(wa.x + 4, Math.min(wa.x + wa.width - w - 4, Math.round(origin.x)));
    const cy = Math.max(wa.y + 4, Math.min(wa.y + wa.height - h - 4, Math.round(origin.y)));
    this.companionOrigin = { x: cx, y: cy };

    if (!this.companionWin || this.companionWin.isDestroyed()) {
      const win = new BrowserWindow({
        x: cx, y: cy, width: w, height: h,
        frame: false, transparent: true, resizable: false,
        minimizable: false, maximizable: false, fullscreenable: false,
        skipTaskbar: true, hasShadow: false, alwaysOnTop: true,
        backgroundColor: '#00000000',
        icon: this.getAssetPath('icon.ico'),
        webPreferences: {
          preload: this.preloadPath(),
          contextIsolation: true,
          nodeIntegration: false,
        },
      });
      win.setAlwaysOnTop(true, 'screen-saver');
      win.moveTop();
      win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
      win.setIgnoreMouseEvents(true, { forward: true });
      // Load desktop.html with ?mascot=moko param so DesktopApp detects companion mode
      this.loadWindowPage(win, 'desktop.html');
      // Inject mascot=moko after load via executeJavaScript so DesktopApp detects companion mode
      win.webContents.once('did-finish-load', () => {
        if (!win.isDestroyed()) {
          void win.webContents.executeJavaScript(
            'window.__MAKI_COMPANION__ = "moko"; history.replaceState(null,"",location.pathname + "?mascot=moko");'
          );
        }
      });
      this.companionWin = win;
    } else {
      this.companionWin.setBounds({ x: cx, y: cy, width: w, height: h });
      this.companionWin.showInactive();
      this.companionWin.setAlwaysOnTop(true, 'screen-saver');
      this.companionWin.moveTop();
    }
  }

  private hideCompanionWindow() {
    this.stopCompanionWalk();
    this.stopBanterTimer();
    if (this.companionWin && !this.companionWin.isDestroyed()) {
      this.companionWin.hide();
    }
  }

  private destroyCompanionWindow() {
    this.stopCompanionWalk();
    this.stopBanterTimer();
    if (this.companionWin && !this.companionWin.isDestroyed()) {
      this.companionWin.destroy();
      this.companionWin = null;
    }
  }

  private syncCompanionWithScreens() {
    const displays = screen.getAllDisplays();
    const primary = screen.getPrimaryDisplay();
    const extDisplays = displays.filter(d => d.id !== primary.id);

    if (extDisplays.length > 0 && this.isOnDesktop) {
      const ext = extDisplays[0];
      const wa = ext.workArea;
      const spawnX = Math.round(wa.x + (wa.width - DESKTOP_NORMAL_WIDTH) / 2);
      const spawnY = wa.y + 28;
      if (!this.companionWin || this.companionWin.isDestroyed()) {
        this.showCompanionWindow({ x: spawnX, y: spawnY });
        // Greeting bubbles
        setTimeout(() => {
          this.showCompanionBubble('👋 Halo Maki! Aku nemenin di monitor sebelah ya!', 3500);
          setTimeout(() => {
            this.showDesktopBubble('🍊 Asik! Selamat datang Moko, santai bareng ya!', 3500);
            this.scheduleBroadcast();
          }, 2000);
          this.scheduleBroadcast();
        }, 600);
        this.startBanterTimer();
        this.startCompanionStroll();
      }
    } else {
      if (this.companionWin && !this.companionWin.isDestroyed()) {
        this.showCompanionBubble('Dadaah Maki, sampai ketemu lagi ya! 👋', 1500);
        this.scheduleBroadcast();
        setTimeout(() => this.destroyCompanionWindow(), 1400);
      }
    }
  }

  // Companion walk
  private startCompanionStroll() {
    if (this.companionWalkTimer) return;
    this.companionWalkTimer = setInterval(() => {
      if (!this.companionWin || this.companionWin.isDestroyed()) return;
      if (!this.companionRoamEnabled) return;
      const bounds = this.companionWin.getBounds();
      const display = screen.getDisplayMatching(bounds);
      const wa = display.workArea;
      const tx = Math.random() * (wa.width - DESKTOP_NORMAL_WIDTH) + wa.x + 10;
      const ty = wa.y + 28 + Math.random() * (wa.height - DESKTOP_NORMAL_HEIGHT - 60);
      this.companionWalkTarget = { x: tx, y: ty };
      this.companionFacingRight = tx > bounds.x;
      this.companionAction = 'walking';
      this.scheduleBroadcast();
      this.stepCompanionWalk();
    }, 30000);
  }

  private stepCompanionWalk() {
    if (!this.companionWalkTarget || !this.companionWin || this.companionWin.isDestroyed()) return;
    const target = this.companionWalkTarget;
    const b = this.companionWin.getBounds();
    const dx = target.x - b.x;
    const dy = target.y - b.y;
    const dist = Math.hypot(dx, dy);
    const step = 2.4;
    if (dist <= step) {
      this.companionWin.setBounds({ x: Math.round(target.x), y: Math.round(target.y), width: b.width, height: b.height });
      this.companionOrigin = { x: Math.round(target.x), y: Math.round(target.y) };
      this.companionWalkTarget = null;
      this.companionAction = 'chill';
      this.scheduleBroadcast();
    } else {
      const nx = b.x + (dx / dist) * step;
      const ny = b.y + (dy / dist) * step;
      this.companionWin.setBounds({ x: Math.round(nx), y: Math.round(ny), width: b.width, height: b.height });
      this.companionOrigin = { x: Math.round(nx), y: Math.round(ny) };
      setTimeout(() => this.stepCompanionWalk(), 1000 / 30);
    }
  }

  private stopCompanionWalk() {
    if (this.companionWalkTimer) {
      clearInterval(this.companionWalkTimer);
      this.companionWalkTimer = null;
    }
    this.companionWalkTarget = null;
    this.companionAction = 'chill';
  }

  // Banter
  private startBanterTimer() {
    this.stopBanterTimer();
    this.banterTimer = setInterval(() => {
      if (!this.companionWin || this.companionWin.isDestroyed()) return;
      if (this.companionBubble || this.desktopBubble) return;
      const pair = this.banterPairs[this.banterIndex % this.banterPairs.length];
      this.banterIndex++;
      this.showDesktopBubble(pair.maki, 3500);
      setTimeout(() => {
        this.showCompanionBubble(pair.moko, 3800);
        this.scheduleBroadcast();
      }, 2000);
      this.scheduleBroadcast();
    }, 60000);
  }

  private stopBanterTimer() {
    if (this.banterTimer) { clearInterval(this.banterTimer); this.banterTimer = null; }
  }

  private showCompanionBubble(text: string, duration = 3000) {
    if (this.companionBubbleTimer) clearTimeout(this.companionBubbleTimer);
    this.companionBubble = text;
    this.companionBubbleTimer = setTimeout(() => {
      this.companionBubble = null;
      this.scheduleBroadcast();
    }, duration);
    this.scheduleBroadcast();
  }

  private syncDesktopWindowSizeForChat() {
    if (!this.desktopWin || this.desktopWin.isDestroyed() || !this.desktopWin.isVisible()) return;
    const bounds = this.desktopWin.getBounds();
    const targetW = this.gemini.isDesktopChatOpen ? DESKTOP_CHAT_WIDTH : DESKTOP_NORMAL_WIDTH;
    const targetH = this.gemini.isDesktopChatOpen ? DESKTOP_CHAT_HEIGHT : DESKTOP_NORMAL_HEIGHT;
    if (bounds.width === targetW && bounds.height === targetH) return;

    // Keep bottom-center of Maki anchored!
    const bottomY = bounds.y + bounds.height;
    const centerX = bounds.x + bounds.width / 2;
    const currentDisplay = screen.getDisplayMatching(bounds);
    const wa = currentDisplay.workArea;
    const newX = Math.max(wa.x + 4, Math.min(wa.x + wa.width - targetW - 4, Math.round(centerX - targetW / 2)));
    const newY = Math.max(wa.y + 4, Math.min(wa.y + wa.height - targetH - 4, Math.round(bottomY - targetH)));
    this.desktopWin.setBounds({ x: newX, y: newY, width: targetW, height: targetH });
    if (this.gemini.isDesktopChatOpen) {
      this.desktopWin.focus();
    }
  }

  private isPointInsideActiveNotch(pt: { x: number; y: number }): boolean {
    if (!this.islandWin || this.islandWin.isDestroyed() || !this.isIslandVisible) return false;
    const b = this.islandWin.getBounds();
    const target = computeTargetIslandSize(this.buildStateSnapshot());
    const padW = this.isExpanded ? 12 : 24;
    const padH = this.isExpanded ? 10 : 8;
    const activeW = target.width + (this.isCompactHovering && !this.isExpanded ? 18 : 0) + padW;
    const activeH = target.height + padH;
    const left = b.x + (b.width - activeW) / 2;
    const right = left + activeW;
    const top = b.y - 2;
    const bottom = b.y + activeH;
    return pt.x >= left && pt.x <= right && pt.y >= top && pt.y <= bottom;
  }

  private isPointInsideDesktopMakiBody(pt: { x: number; y: number }): boolean {
    if (!this.desktopWin || this.desktopWin.isDestroyed() || !this.isOnDesktop) return false;
    const b = this.desktopWin.getBounds();
    if (this.gemini.isDesktopChatOpen) {
      return pt.x >= b.x && pt.x <= b.x + b.width && pt.y >= b.y && pt.y <= b.y + b.height;
    }
    const midX = b.x + b.width / 2;
    const bottomY = b.y + b.height;
    // Maki's body sits in the bottom-center (126w x 146h from bottom)
    const inBody =
      pt.x >= midX - 63 &&
      pt.x <= midX + 63 &&
      pt.y >= bottomY - 148 &&
      pt.y <= bottomY;
    if (inBody) return true;
    // When dock is already revealed by hover, include the 236x34 quick-dock pill at bottom
    if (this.desktopPointerInside) {
      const inDock =
        pt.x >= midX - 118 &&
        pt.x <= midX + 118 &&
        pt.y >= bottomY - 36 &&
        pt.y <= bottomY + 2;
      if (inDock) return true;
    }
    return false;
  }

  private get isHeldForDrop(): boolean {
    return this.isMouthOpenForDrop || Date.now() < this.dropHoldUntil;
  }

  public holdForDrop(ms = 3000) {
    this.dropHoldUntil = Math.max(this.dropHoldUntil, Date.now() + ms);
    this.walkTarget = null;
    this.throwVel = { x: 0, y: 0 };
    if (this.isChasingCursor) this.isChasingCursor = false;
    if (this.homePhase.kind === 'none' && this.currentAction === 'walking') {
      this.currentAction = 'chill';
    }
  }

  private updateClickThroughAndGaze() {
    const cursor = screen.getCursorScreenPoint();

    // 1. Dynamic Island window click-through
    if (this.islandWin && !this.islandWin.isDestroyed() && this.isIslandVisible) {
      if (this.isNativeFileDragging) {
        if (this.islandIgnoreMouse !== false) {
          this.islandIgnoreMouse = false;
          this.islandWin.setIgnoreMouseEvents(false);
        }
      } else {
        const hitNotch = this.isPointInsideActiveNotch(cursor) || this.isHeldForDrop;
        const shouldIgnore = !hitNotch;
        if (this.islandIgnoreMouse !== shouldIgnore) {
          this.islandIgnoreMouse = shouldIgnore;
          this.islandWin.setIgnoreMouseEvents(shouldIgnore, { forward: true });
        }
      }
    }

    // 2. Desktop Maki window body-only click-through
    if (this.desktopWin && !this.desktopWin.isDestroyed() && this.isOnDesktop) {
      const hitBody =
        this.isWindowDragActive ||
        this.isHeldForDrop ||
        (!this.isReturningToNotch && this.isPointInsideDesktopMakiBody(cursor));

      if (this.desktopPointerInside !== hitBody) {
        this.desktopPointerInside = hitBody;
        this.scheduleBroadcast();
      }

      const shouldIgnore = !hitBody;
      if (this.desktopIgnoreMouse !== shouldIgnore) {
        this.desktopIgnoreMouse = shouldIgnore;
        this.desktopWin.setIgnoreMouseEvents(shouldIgnore, { forward: true });
      }
    }

    // 3. Global real-time eye & head cursor gaze tracking
    let anchorX = 0;
    let anchorY = 0;
    if (this.isOnDesktop && this.desktopWin && !this.desktopWin.isDestroyed()) {
      const b = this.desktopWin.getBounds();
      anchorX = b.x + b.width / 2;
      anchorY = b.y + b.height - 88;
    } else if (this.islandWin && !this.islandWin.isDestroyed()) {
      const b = this.islandWin.getBounds();
      anchorX = b.x + b.width / 2 + (this.isExpanded ? 240 : 80);
      anchorY = b.y + (this.isExpanded ? 92 : 18);
    }

    const nx = Math.max(-1, Math.min(1, (cursor.x - anchorX) / 220));
    const ny = Math.max(-1, Math.min(1, (cursor.y - anchorY) / 180));
    const sx = this.lookVector.x * 0.65 + nx * 0.35;
    const sy = this.lookVector.y * 0.65 + ny * 0.35;
    if (Math.abs(sx - this.lookVector.x) > 0.035 || Math.abs(sy - this.lookVector.y) > 0.035) {
      this.lookVector = { x: Math.round(sx * 100) / 100, y: Math.round(sy * 100) / 100 };
      this.scheduleBroadcast();
    }
  }

  // --- Desktop Physics, Stroll, Chase & 2-Phase Walk Home into Notch ---
  private tickDesktopMotion(dtSec: number) {
    if (!this.isOnDesktop || !this.desktopWin || this.desktopWin.isDestroyed()) return;
    if (this.isWindowDragActive) return;

    const b = this.desktopWin.getBounds();
    const currentDisplay = screen.getDisplayMatching(b);
    const wa = currentDisplay.workArea;
    const minX = wa.x + 4;
    const maxX = wa.x + wa.width - b.width - 4;
    const minY = wa.y + 4;
    const maxY = wa.y + wa.height - b.height - 4;

    // 1. 2-Phase Walk Home into Top-Center Notch
    if (this.homePhase.kind === 'doorstep') {
      const dx = this.homePhase.doorstepX - b.x;
      const dy = this.homePhase.doorstepY - b.y;
      const dist = Math.hypot(dx, dy);
      if (dist < 6) {
        this.desktopWin.setPosition(Math.round(this.homePhase.doorstepX), Math.round(this.homePhase.doorstepY));
        this.homePhase = {
          kind: 'climbing',
          doorstepX: this.homePhase.doorstepX,
          doorstepY: this.homePhase.doorstepY,
          insideY: this.homePhase.insideY,
          progress: 0,
        };
        return;
      }
      const step = Math.min(dist, 360 * dtSec);
      const nx = b.x + (dx / dist) * step;
      const ny = b.y + (dy / dist) * step;
      this.facingRight = dx >= 0;
      this.desktopWin.setPosition(Math.round(nx), Math.round(ny));
      return;
    }

    if (this.homePhase.kind === 'climbing') {
      const nextProg = Math.min(1, this.homePhase.progress + dtSec * 2.5);
      this.homePhase.progress = nextProg;
      this.notchClimbProgress = nextProg;
      const curY =
        this.homePhase.doorstepY + (this.homePhase.insideY - this.homePhase.doorstepY) * nextProg;
      this.desktopWin.setPosition(Math.round(this.homePhase.doorstepX), Math.round(curY));
      this.scheduleBroadcast();
      if (nextProg >= 1) {
        this.completeReturnToNotchArrival();
      }
      return;
    }

    // Hold completely still during file drag-over!
    if (this.isHeldForDrop) return;

    // 2. Throw & Bounce Physics
    const speed = Math.hypot(this.throwVel.x, this.throwVel.y);
    if (speed > 12) {
      let nx = b.x + this.throwVel.x * dtSec;
      let ny = b.y + this.throwVel.y * dtSec;
      const damp = Math.pow(0.92, dtSec * 60);
      this.throwVel.x *= damp;
      this.throwVel.y *= damp;

      let bounced = false;
      if (nx < minX) {
        nx = minX;
        this.throwVel.x = Math.abs(this.throwVel.x) * 0.72;
        bounced = true;
      } else if (nx > maxX) {
        nx = maxX;
        this.throwVel.x = -Math.abs(this.throwVel.x) * 0.72;
        bounced = true;
      }
      if (ny < minY) {
        ny = minY;
        this.throwVel.y = Math.abs(this.throwVel.y) * 0.72;
        bounced = true;
      } else if (ny > maxY) {
        ny = maxY;
        this.throwVel.y = -Math.abs(this.throwVel.y) * 0.72;
        bounced = true;
      }

      if (bounced) this.registerSquish();
      this.desktopWin.setPosition(Math.round(nx), Math.round(ny));
      if (Math.hypot(this.throwVel.x, this.throwVel.y) <= 12) {
        this.throwVel = { x: 0, y: 0 };
        this.desktopOrigin = { x: Math.round(nx), y: Math.round(ny) };
        this.savePersisted();
        this.registerSquish();
      }
      return;
    }

    // 3. Chase Cursor Mini-Game
    if (this.isChasingCursor) {
      const cursor = screen.getCursorScreenPoint();
      const petCx = b.x + b.width * 0.5;
      const petCy = b.y + b.height * 0.6;
      const dx = cursor.x - petCx;
      const dy = cursor.y - petCy;
      const dist = Math.hypot(dx, dy);
      if (dist < 44) {
        this.desktopOrigin = { x: b.x, y: b.y };
        this.savePersisted();
        this.stopChaseCursor(true);
        return;
      }
      const step = Math.min(dist, 245 * dtSec);
      const nx = Math.max(minX, Math.min(maxX, b.x + (dx / dist) * step));
      const ny = Math.max(minY, Math.min(maxY, b.y + (dy / dist) * step));
      this.facingRight = dx >= 0;
      if (this.currentAction !== 'walking') this.currentAction = 'walking';
      this.desktopWin.setPosition(Math.round(nx), Math.round(ny));
      return;
    }

    // 4. Autonomous Cozy Stroll
    if (this.walkTarget) {
      if (this.desktopPointerInside) {
        if (this.currentAction === 'walking') {
          this.currentAction = 'chill';
          this.scheduleBroadcast();
        }
        return;
      }
      const dx = this.walkTarget.x - b.x;
      const dy = this.walkTarget.y - b.y;
      const dist = Math.hypot(dx, dy);
      if (dist < 5) {
        const fx = Math.max(minX, Math.min(maxX, Math.round(this.walkTarget.x)));
        const fy = Math.max(minY, Math.min(maxY, Math.round(this.walkTarget.y)));
        this.desktopWin.setPosition(fx, fy);
        this.desktopOrigin = { x: fx, y: fy };
        this.savePersisted();
        this.walkTarget = null;
        this.currentAction = 'chill';
        this.scheduleBroadcast();
        return;
      }
      const step = Math.min(dist, 68 * dtSec);
      const nx = Math.max(minX, Math.min(maxX, b.x + (dx / dist) * step));
      const ny = Math.max(minY, Math.min(maxY, b.y + (dy / dist) * step));
      this.facingRight = dx >= 0;
      if (this.currentAction !== 'walking') {
        this.currentAction = 'walking';
        this.scheduleBroadcast();
      }
      this.desktopWin.setPosition(Math.round(nx), Math.round(ny));
    }
  }

  private startAutonomousStroll() {
    if (!this.desktopWin || this.desktopWin.isDestroyed()) return;
    const b = this.desktopWin.getBounds();
    const currentDisplay = screen.getDisplayMatching(b);
    const wa = currentDisplay.workArea;
    const margin = 24;
    const tx =
      wa.x + margin + Math.random() * Math.max(40, wa.width - b.width - margin * 2);
    const roll = Math.random();
    let ty = wa.y + wa.height - b.height - 12;
    if (roll < 0.45) {
      // Lower zone near taskbar / bottom of active application
      ty = wa.y + wa.height - b.height - (8 + Math.random() * 56);
    } else if (roll < 0.80) {
      // Mid-screen across active app (e.g. over Chrome webpage, text, documents)
      ty = wa.y + (wa.height * 0.32) + Math.random() * (wa.height * 0.42);
    } else {
      // Upper zone
      ty = wa.y + margin + Math.random() * Math.max(40, wa.height * 0.28);
    }
    this.walkTarget = { x: tx, y: Math.round(ty) };
    this.facingRight = tx >= b.x;
    this.currentAction = 'walking';
    this.scheduleBroadcast();
  }

  // --- Capybara Companion Actions ---
  private registerSquish() {
    this.lastSquishTime = Date.now() / 1000;
    this.scheduleBroadcast();
  }

  private scheduleActionReset(afterMs: number) {
    if (this.actionResetTimeout) clearTimeout(this.actionResetTimeout);
    this.actionResetTimeout = setTimeout(() => {
      this.currentAction = 'chill';
      this.scheduleBroadcast();
    }, afterMs);
  }

  private showBubble(text: string, ms = 2500) {
    if (this.bubbleTimeout) clearTimeout(this.bubbleTimeout);
    this.speechBubble = text;
    this.scheduleBroadcast();
    this.bubbleTimeout = setTimeout(() => {
      this.speechBubble = null;
      this.scheduleBroadcast();
    }, ms);
  }

  private showContextualTip(text: string, ms = 2400) {
    if (this.tipTimeout) clearTimeout(this.tipTimeout);
    this.contextualTip = text;
    this.scheduleBroadcast();
    this.tipTimeout = setTimeout(() => {
      this.contextualTip = null;
      this.scheduleBroadcast();
    }, ms);
  }

  private showDesktopBubble(text: string, ms = 2600) {
    if (this.deskBubbleTimeout) clearTimeout(this.deskBubbleTimeout);
    this.desktopBubble = text;
    this.scheduleBroadcast();
    this.deskBubbleTimeout = setTimeout(() => {
      this.desktopBubble = null;
      this.scheduleBroadcast();
    }, ms);
  }

  private emitAllBubbles(text: string, fromDesktop = false) {
    if (fromDesktop || this.isOnDesktop) this.showDesktopBubble(text);
    this.showBubble(text);
    this.showContextualTip(text);
  }

  private performRandomIdleActivity(silent = false) {
    this.registerSquish();
    const fg = getFrontAppName();
    const isCoding =
      fg.includes('code') ||
      fg.includes('cursor') ||
      fg.includes('devenv') ||
      fg.includes('windowsterminal') ||
      fg.includes('powershell') ||
      fg.includes('idea');

    const activities: { action: CapyActionType; quotes: string[]; dur: number }[] = [
      { action: 'sippingTea', quotes: ['anget tehnya..', 'nyeruput bentar', 'slurrpp..'], dur: 6500 },
      { action: 'butterflyChase', quotes: ['eh ada kupu-kupu', 'mau kemana tuh..', 'lucu warnanya'], dur: 7000 },
      { action: 'jugglingOranges', quotes: ['satu.. dua.. tiga..', 'awas jangan jatoh..', 'fokus tangkep..'], dur: 7500 },
      { action: 'blowingBubbles', quotes: ['fuuhh..', 'melayang jauh..'], dur: 6500 },
      {
        action: 'typingLaptop',
        quotes: isCoding ? ['ikut ngetik ah..', 'fokus dikit..', 'lagi sibuk ya?'] : ['cek catatan bentar..', 'ketik dikit ah'],
        dur: 7000,
      },
      { action: 'readingBook', quotes: ['baca bentar..', 'seru juga isinya', 'hmm gitu ternyata'], dur: 6500 },
      { action: 'stretching', quotes: ['pegel duduk terus..', 'nguap dulu ah', 'lumayan pegel nih'], dur: 5500 },
    ];

    let idx = 0;
    if (isCoding && silent && Math.random() < 0.35 && this.lastActivityIndex !== 4) {
      idx = 4;
    } else {
      do {
        idx = Math.floor(Math.random() * activities.length);
      } while (idx === this.lastActivityIndex && activities.length > 1);
    }
    this.lastActivityIndex = idx;
    const chosen = activities[idx];
    const phrase = chosen.quotes[Math.floor(Math.random() * chosen.quotes.length)];

    if (this.isOnsenMode) this.isOnsenMode = false;
    this.currentAction = chosen.action;

    if (!silent || Math.random() < 0.45) {
      if (this.isOnDesktop) this.showDesktopBubble(phrase, 2600);
      this.showBubble(phrase, 2600);
    }
    if (!silent) {
      this.showContextualTip(phrase, 2500);
      this.xp += 4;
    }
    this.savePersisted();
    this.scheduleActionReset(chosen.dur);
    this.scheduleBroadcast();
  }

  public triggerSpecificActivity(action: CapyActionType, message: string, durMs = 7500) {
    if (this.isReturningToNotch) return;
    this.isChasingCursor = false;
    this.walkTarget = null;
    this.registerSquish();
    if (this.isOnsenMode) this.isOnsenMode = false;
    this.currentAction = action;
    if (this.isOnDesktop) this.showDesktopBubble(message, 2800);
    this.showBubble(message, 2800);
    this.showContextualTip(message, 2500);
    this.xp += 4;
    this.savePersisted();
    this.scheduleActionReset(durMs);
    this.scheduleBroadcast();
  }

  public interactInTab(tab: IslandTab, fromDesktop = false) {
    if (this.isReturningToNotch) return;
    const now = Date.now();
    this.pokeStreak = now - this.lastPokeTime < 2200 ? this.pokeStreak + 1 : 1;
    this.lastPokeTime = now;
    this.registerSquish();

    if (this.currentAction === 'sleeping') {
      this.currentAction = 'ticklish';
      const msg = Math.random() < 0.5 ? 'eh kaget.. ketiduran tadi' : 'hmm? udah bangun kok';
      this.emitAllBubbles(msg, fromDesktop);
      this.scheduleActionReset(1800);
      return;
    }

    if (this.pokeStreak >= 5) {
      this.currentAction = 'dizzy';
      const msg = DIZZY_QUOTES[Math.floor(Math.random() * DIZZY_QUOTES.length)];
      this.emitAllBubbles(msg, fromDesktop);
      this.scheduleActionReset(2300);
      return;
    }
    if (this.pokeStreak >= 3) {
      this.currentAction = 'ticklish';
      this.xp += 2;
      const msg = TICKLISH_QUOTES[Math.floor(Math.random() * TICKLISH_QUOTES.length)];
      this.emitAllBubbles(msg, fromDesktop);
      this.savePersisted();
      this.scheduleActionReset(1700);
      return;
    }

    this.mood = Math.min(100, this.mood + 5);
    this.xp += 5;
    this.heartBurstSeq += 1;
    this.currentAction = 'happyPet';

    let line = PET_QUOTES[Math.floor(Math.random() * PET_QUOTES.length)];
    const track = getCurrentTrackSnapshot();
    const sys = getSystemMetricsSnapshot();
    switch (tab) {
      case 'maki-land':
        line = track.isPlaying ? 'enak lagunya..' : 'sepi nih, setel lagu yuk';
        break;
      case 'Notes': {
        const rem = this.todos.filter((t) => !t.isDone).length;
        line = rem === 0 && this.todos.length > 0 ? 'semua tugas udah beres nih' : 'pelan-pelan dicicil aja';
        break;
      }
      case 'Launch':
        line = 'mau buka aplikasi apa?';
        break;
      case 'Tray':
        line =
          this.studio.getSnapshot().droppedItems.length > 0
            ? 'tinggal tarik keluar kalau mau pakai'
            : 'kasih screenshot ke aku juga bisa';
        break;
      case 'System':
        line = sys.cpuPercent >= 60 ? 'lumayan kerja keras nih pc-nya' : 'mesinnya masih adem kok';
        break;
      case 'Clipboard':
        line = 'klik aja buat salin ulang';
        break;
      case 'Timer':
        line = this.timerRunning ? 'fokus dulu bentar ya..' : 'mau mulai fokus pakai timer?';
        break;
    }

    this.emitAllBubbles(line, fromDesktop);
    this.savePersisted();
    this.scheduleActionReset(1700);
  }

  public feed(food: CapyFood) {
    if (this.isReturningToNotch) return;
    this.walkTarget = null;
    this.isChasingCursor = false;
    this.pokeStreak = 0;
    this.registerSquish();
    this.fullness = Math.min(100, this.fullness + 16);
    this.mood = Math.min(100, this.mood + 6);
    this.xp += 10;
    this.heartBurstSeq += 1;
    const found = CAPY_FOODS.find((f) => f.id === food);
    this.eatingEmoji = found?.emoji || '🍊';
    this.currentAction = 'eating';

    const msg =
      food === 'Jeruk'
        ? 'seger banget jeruknya..'
        : food === 'Semangka'
        ? 'adem makan semangka..'
        : 'kriuk.. sehat juga';
    this.emitAllBubbles(msg, this.isOnDesktop);
    this.savePersisted();
    this.scheduleActionReset(2300);
  }

  public cycleOranges() {
    this.registerSquish();
    this.orangesOnHead = (this.orangesOnHead + 1) % 4;
    this.xp += 3;
    const msgs = [
      'enteng lagi kepalaku',
      'satu jeruk pas di kepala',
      'dua jeruk.. tahan jangan goyang',
      'tiga jeruk nih, lumayan berat..',
    ];
    this.emitAllBubbles(msgs[this.orangesOnHead], this.isOnDesktop);
    this.savePersisted();
  }

  public async cleanCacheInteractive() {
    this.registerSquish();
    this.currentAction = 'brushed';
    this.emitAllBubbles('Hup! Tunggu bentar ya, Maki bersihkan sampah cache dulu~ 🧹', this.isOnDesktop);
    this.scheduleBroadcast();

    const result = await this.cleaner.cleanSafeCache((step) => {
      if (this.isOnDesktop) {
        this.desktopBubble = step;
        this.scheduleBroadcast();
      }
    });

    if (result.freedBytes > 0) {
      this.xp += 10;
      this.mood = Math.min(100, this.mood + 5);
      const freedStr = this.cleaner.formatBytes(result.freedBytes);
      this.emitAllBubbles(`Selesai! Berhasil memindahkan ${freedStr} sampah ke Recycle Bin! 🐾✨`, this.isOnDesktop);
    } else {
      this.emitAllBubbles('Laptopmu udah kinclong, nggak ada cache yang perlu dibuang! ✨', this.isOnDesktop);
    }

    this.savePersisted();
    this.scheduleActionReset(2500);
    this.scheduleBroadcast();
  }

  public toggleOnsen() {
    this.walkTarget = null;
    this.isChasingCursor = false;
    this.registerSquish();
    this.isOnsenMode = !this.isOnsenMode;
    if (this.isOnsenMode) {
      this.posX = 0;
      this.currentAction = 'chill';
      if (this.orangesOnHead === 0) this.orangesOnHead = 1;
      this.mood = Math.min(100, this.mood + 10);
      this.emitAllBubbles('anget banget airnya..', this.isOnDesktop);
    } else {
      this.emitAllBubbles('seger habis berendam', this.isOnDesktop);
    }
    this.savePersisted();
    this.scheduleBroadcast();
  }

  public startChaseCursor() {
    if (this.isReturningToNotch) {
      this.homePhase = { kind: 'none' };
      this.isReturningToNotch = false;
      this.notchClimbProgress = 0;
    }
    if (!this.isOnDesktop) {
      this.releaseToDesktop();
    }
    if (this.isOnsenMode) this.isOnsenMode = false;
    this.isChasingCursor = true;
    this.currentAction = 'walking';
    this.showDesktopBubble('tungguin, ikut..', 2600);

    if (this.chaseStopTimeout) clearTimeout(this.chaseStopTimeout);
    this.chaseStopTimeout = setTimeout(() => {
      this.stopChaseCursor(false);
    }, 12000);
    this.scheduleBroadcast();
  }

  public stopChaseCursor(caught: boolean) {
    if (!this.isChasingCursor) return;
    if (this.chaseStopTimeout) clearTimeout(this.chaseStopTimeout);
    this.isChasingCursor = false;
    this.registerSquish();
    if (caught) {
      this.xp += 8;
      this.mood = Math.min(100, this.mood + 8);
      this.heartBurstSeq += 1;
      this.currentAction = 'happyPet';
      this.showDesktopBubble('dapet kursormu hehe', 2500);
      this.scheduleActionReset(2000);
    } else {
      this.currentAction = 'stretching';
      this.showDesktopBubble('hah.. capek juga lari', 2500);
      this.scheduleActionReset(2200);
    }
    this.savePersisted();
    this.scheduleBroadcast();
  }

  public releaseToDesktop(atPoint?: { x: number; y: number }) {
    this.homePhase = { kind: 'none' };
    this.isReturningToNotch = false;
    this.notchClimbProgress = 0;
    if (atPoint) {
      this.desktopOrigin = { x: atPoint.x - 132, y: atPoint.y - 100 };
    }
    this.isOnDesktop = true;
    this.savePersisted();
    this.registerSquish();
    this.showDesktopWindow(this.desktopOrigin);
    this.showDesktopBubble('main di bawah dulu ya..', 2500);
    this.rebuildTrayMenu();
    this.scheduleBroadcast();
    // Spawn companion Moko on extended display if connected
    setTimeout(() => this.syncCompanionWithScreens(), 500);
  }

  public returnToNotch() {
    if (!this.isOnDesktop || this.isReturningToNotch) return;
    this.isDraggingOnDesktop = false;
    this.isChasingCursor = false;
    this.walkTarget = null;
    this.notchClimbProgress = 0;
    if (this.gemini.isDesktopChatOpen) {
      this.gemini.isDesktopChatOpen = false;
      this.syncDesktopWindowSizeForChat();
    }
    if (this.isOnsenMode) this.isOnsenMode = false;

    if (this.desktopWin && !this.desktopWin.isDestroyed() && this.desktopWin.isVisible()) {
      const primary = screen.getPrimaryDisplay();
      const doorstepX = Math.round(primary.bounds.x + (primary.bounds.width - DESKTOP_NORMAL_WIDTH) / 2);
      const doorstepY = primary.bounds.y + 8;
      const insideY = primary.bounds.y - 84;
      this.isReturningToNotch = true;
      this.currentAction = 'walking';
      this.showDesktopBubble('pulang ke notch ah..', 2000);
      this.homePhase = { kind: 'doorstep', doorstepX, doorstepY, insideY };
      this.scheduleBroadcast();
    } else {
      this.completeReturnToNotchArrival();
    }
  }

  private completeReturnToNotchArrival() {
    this.homePhase = { kind: 'none' };
    this.isReturningToNotch = false;
    this.notchClimbProgress = 0;
    this.isDraggingOnDesktop = false;
    this.isChasingCursor = false;
    if (!this.showInCompactNotch) this.showInCompactNotch = true;
    this.hideDesktopWindow();
    this.isOnDesktop = false;
    this.currentAction = 'chill';
    this.registerSquish();
    this.showBubble('udah nyampe di atas..', 2200);
    this.showContextualTip('udah balik di notch', 2000);
    this.savePersisted();
    this.rebuildTrayMenu();
    // Companion says goodbye and disappears
    this.syncCompanionWithScreens();
    this.scheduleBroadcast();
  }

  public setExpanded(expanded: boolean) {
    if (this.isExpanded === expanded) return;
    if (!expanded) {
      this.collapseCooldownUntil = Date.now() + 420;
      this.isCompactHovering = false;
    }
    this.isExpanded = expanded;
    if (expanded && this.islandWin && !this.islandWin.isDestroyed()) {
      this.islandWin.focus();
    }
    this.scheduleBroadcast();
  }

  // --- Swallow Files into Tray ---
  public async swallowFilesIntoTray(paths: string[]) {
    if (!paths || paths.length === 0) return;
    this.isMouthOpenForDrop = false;
    const added = await this.studio.addFilePaths(paths, false);
    if (added.length === 0) return;
    this.registerSquish();
    this.currentAction = 'swallowing';
    this.xp += 12;
    this.heartBurstSeq += 1;
    this.selectedTab = 'Tray';
    this.setExpanded(true);
    this.emitAllBubbles('udah masuk Tray ya, tinggal ambil', this.isOnDesktop);
    this.savePersisted();
    this.scheduleActionReset(1800);
  }

  // --- Calendar (.ics + Local) ---
  public async syncGoogleICS(url: string) {
    this.googleICSUrl = (url || '').trim().replace(/^["']|["']$/g, '');
    this.savePersisted();
    if (!this.googleICSUrl) {
      this.icsCalendarEvents = [];
      this.calendarError = null;
      this.scheduleBroadcast();
      return;
    }

    this.isSyncingICS = true;
    this.calendarError = null;
    this.scheduleBroadcast();
    try {
      let normalized = this.googleICSUrl.replace(/^webcal:\/\//i, 'https://');
      if (!/^https?:\/\//i.test(normalized)) {
        normalized = `https://${normalized}`;
      }

      const res = await fetch(normalized, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 maki-land/1.0.0',
          Accept: 'text/calendar, text/plain, */*',
          'Cache-Control': 'no-cache',
        },
        redirect: 'follow',
        signal: AbortSignal.timeout(15000),
      });

      if (res.status === 401 || res.status === 403) {
        throw new Error(
          'Akses ditolak (403/401). Di Google Calendar, gunakan "Alamat rahasia dalam format iCal", bukan URL publik yang dikunci.'
        );
      }
      if (res.status === 404) {
        throw new Error('Kalender tidak ditemukan (404). Periksa kembali tautan .ics Anda.');
      }
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      }

      const raw = await res.text();
      if (!raw.includes('BEGIN:VCALENDAR')) {
        if (raw.includes('<!DOCTYPE html>') || raw.includes('<html') || raw.includes('<head>')) {
          throw new Error(
            'Tautan ini membuka halaman web, bukan file kalender .ics. Buka Google Calendar di browser > Settings > Integrasikan Kalender > salin "Alamat rahasia dalam format iCal".'
          );
        }
        throw new Error('Format kalender tidak dikenali (bukan iCalendar .ics)');
      }

      this.icsCalendarEvents = MakiMainController.parseICS(raw);
      if (this.icsCalendarEvents.length === 0) {
        this.calendarError = 'Kalender terhubung! Tidak ada agenda dalam 30 hari terakhir hingga 90 hari ke depan.';
      } else {
        this.calendarError = null;
      }
    } catch (e) {
      this.calendarError = `Gagal sinkron .ics: ${(e as Error).message}`;
    } finally {
      this.isSyncingICS = false;
      this.scheduleBroadcast();
    }
  }

  private static formatLocalISO(d: Date): string {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  private static parseICSDate(rawVal: string): {
    dateISO: string;
    timeLabel: string;
    isAllDay: boolean;
    dateObj: Date;
  } | null {
    const v = rawVal.trim();
    if (v.length < 8) return null;
    const y = parseInt(v.slice(0, 4), 10);
    const m = parseInt(v.slice(4, 6), 10);
    const d = parseInt(v.slice(6, 8), 10);

    if (!v.includes('T')) {
      const dateISO = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      return { dateISO, timeLabel: 'Seharian', isAllDay: true, dateObj: new Date(y, m - 1, d) };
    }

    const tPart = v.slice(v.indexOf('T') + 1);
    const hh = parseInt(tPart.slice(0, 2), 10);
    const mm = parseInt(tPart.slice(2, 4), 10);
    const ss = tPart.length >= 6 ? parseInt(tPart.slice(4, 6), 10) : 0;

    if (v.endsWith('Z')) {
      const utcDate = new Date(Date.UTC(y, m - 1, d, hh, mm, ss));
      const dateISO = MakiMainController.formatLocalISO(utcDate);
      const timeLabel = `${String(utcDate.getHours()).padStart(2, '0')}:${String(utcDate.getMinutes()).padStart(2, '0')}`;
      return { dateISO, timeLabel, isAllDay: false, dateObj: utcDate };
    }

    const localDate = new Date(y, m - 1, d, hh, mm, ss);
    const dateISO = MakiMainController.formatLocalISO(localDate);
    const timeLabel = `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
    return { dateISO, timeLabel, isAllDay: false, dateObj: localDate };
  }

  private static expandRecurrence(
    startParsed: { dateISO: string; timeLabel: string; isAllDay: boolean; dateObj: Date },
    rruleStr: string,
    now: Date,
    daysBack = 30,
    daysForward = 90
  ): { dateISO: string; timeLabel: string; isAllDay: boolean }[] {
    const results: { dateISO: string; timeLabel: string; isAllDay: boolean }[] = [];
    const windowStart = new Date(now.getTime() - daysBack * 86400000);
    const windowEnd = new Date(now.getTime() + daysForward * 86400000);

    const rules: Record<string, string> = {};
    rruleStr.split(';').forEach((p) => {
      const [k, v] = p.split('=');
      if (k && v) rules[k.toUpperCase()] = v.toUpperCase();
    });

    const freq = rules['FREQ'];
    if (!freq) return results;

    const interval = Math.max(1, parseInt(rules['INTERVAL'] || '1', 10));
    let untilDate: Date | null = null;
    if (rules['UNTIL']) {
      const u = rules['UNTIL'];
      if (u.length >= 8) {
        const uy = parseInt(u.slice(0, 4), 10);
        const um = parseInt(u.slice(4, 6), 10);
        const ud = parseInt(u.slice(6, 8), 10);
        untilDate = new Date(uy, um - 1, ud, 23, 59, 59);
      }
    }
    const maxCount = rules['COUNT'] ? parseInt(rules['COUNT'], 10) : 365;

    const dayMap: Record<string, number> = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
    const byDays = rules['BYDAY']
      ? rules['BYDAY']
          .split(',')
          .map((d) => dayMap[d.trim()])
          .filter((x): x is number => x !== undefined)
      : null;

    const cur = new Date(startParsed.dateObj.getTime());
    let emitted = 0;

    // Fast-forward cur if start date is far in the past
    if (freq === 'WEEKLY' && cur < windowStart) {
      const diffWeeks = Math.floor((windowStart.getTime() - cur.getTime()) / (7 * 86400000 * interval));
      if (diffWeeks > 1) {
        cur.setDate(cur.getDate() + diffWeeks * 7 * interval);
      }
    } else if (freq === 'DAILY' && cur < windowStart) {
      const diffDays = Math.floor((windowStart.getTime() - cur.getTime()) / (86400000 * interval));
      if (diffDays > 1) {
        cur.setDate(cur.getDate() + diffDays * interval);
      }
    } else if (freq === 'YEARLY' && cur < windowStart) {
      const diffYears = windowStart.getFullYear() - cur.getFullYear() - 1;
      if (diffYears > 0) {
        cur.setFullYear(cur.getFullYear() + diffYears * interval);
      }
    }

    let iterations = 0;
    while (cur <= windowEnd && emitted < maxCount && iterations < 1200) {
      iterations++;
      if (untilDate && cur > untilDate) break;

      if (freq === 'WEEKLY' && byDays && byDays.length > 0) {
        if (byDays.includes(cur.getDay()) && cur >= windowStart) {
          results.push({
            dateISO: MakiMainController.formatLocalISO(cur),
            timeLabel: startParsed.timeLabel,
            isAllDay: startParsed.isAllDay,
          });
          emitted++;
        }
        cur.setDate(cur.getDate() + 1);
      } else {
        if (cur >= windowStart) {
          results.push({
            dateISO: MakiMainController.formatLocalISO(cur),
            timeLabel: startParsed.timeLabel,
            isAllDay: startParsed.isAllDay,
          });
          emitted++;
        }
        if (freq === 'DAILY') {
          cur.setDate(cur.getDate() + interval);
        } else if (freq === 'WEEKLY') {
          cur.setDate(cur.getDate() + 7 * interval);
        } else if (freq === 'MONTHLY') {
          cur.setMonth(cur.getMonth() + interval);
        } else if (freq === 'YEARLY') {
          cur.setFullYear(cur.getFullYear() + interval);
        } else {
          break;
        }
      }
    }

    return results;
  }

  private static parseICS(icsText: string): CalendarEventItem[] {
    const unfolded = icsText.replace(/\r?\n[ \t]/g, '');
    const blocks = unfolded.split('BEGIN:VEVENT').slice(1);
    const now = new Date();
    const windowStart = new Date(now.getTime() - 30 * 86400000);
    const windowEnd = new Date(now.getTime() + 90 * 86400000);
    const windowStartISO = MakiMainController.formatLocalISO(windowStart);
    const windowEndISO = MakiMainController.formatLocalISO(windowEnd);

    const results: CalendarEventItem[] = [];
    const seenKeys = new Set<string>();

    for (const block of blocks) {
      const body = block.split('END:VEVENT')[0] || '';
      const lines = body.split(/\r?\n/);
      let summary = '';
      let dtStartRaw = '';
      let uid = '';
      let rrule = '';

      for (const line of lines) {
        if (line.startsWith('SUMMARY')) {
          summary = line.slice(line.indexOf(':') + 1).trim();
        } else if (line.startsWith('DTSTART')) {
          dtStartRaw = line.slice(line.indexOf(':') + 1).trim();
        } else if (line.startsWith('UID:')) {
          uid = line.slice(4).trim();
        } else if (line.startsWith('RRULE:')) {
          rrule = line.slice(6).trim();
        }
      }

      if (!summary || !dtStartRaw) continue;
      const parsedStart = MakiMainController.parseICSDate(dtStartRaw);
      if (!parsedStart) continue;

      const cleanTitle = summary
        .replace(/\\,/g, ',')
        .replace(/\\;/g, ';')
        .replace(/\\n/g, ' ')
        .replace(/\\\\/g, '\\')
        .trim();
      const baseId = uid || crypto.randomUUID();

      if (rrule) {
        const instances = MakiMainController.expandRecurrence(parsedStart, rrule, now, 30, 90);
        for (const inst of instances) {
          const dedupeKey = `${baseId}_${inst.dateISO}`;
          if (seenKeys.has(dedupeKey)) continue;
          seenKeys.add(dedupeKey);
          results.push({
            id: dedupeKey,
            title: cleanTitle,
            dateISO: inst.dateISO,
            timeLabel: inst.timeLabel,
            isAllDay: inst.isAllDay,
            source: 'Google',
            colorHex: '#4dabf7',
          });
        }
      } else {
        if (parsedStart.dateISO >= windowStartISO && parsedStart.dateISO <= windowEndISO) {
          const dedupeKey = `${baseId}_${parsedStart.dateISO}`;
          if (!seenKeys.has(dedupeKey)) {
            seenKeys.add(dedupeKey);
            results.push({
              id: dedupeKey,
              title: cleanTitle,
              dateISO: parsedStart.dateISO,
              timeLabel: parsedStart.timeLabel,
              isAllDay: parsedStart.isAllDay,
              source: 'Google',
              colorHex: '#4dabf7',
            });
          }
        }
      }
    }

    results.sort((a, b) => {
      const c = a.dateISO.localeCompare(b.dateISO);
      if (c !== 0) return c;
      return a.timeLabel.localeCompare(b.timeLabel);
    });

    return results.slice(0, 300);
  }

  // --- Launcher Native Icons ---
  private async hydrateLauncherIcons() {
    for (const item of this.launcherItems) {
      if (!item.isWeb && fs.existsSync(item.urlOrPath)) {
        try {
          const icon = await app.getFileIcon(item.urlOrPath, { size: 'normal' });
          if (!icon.isEmpty()) {
            item.iconDataUrl = icon.toDataURL();
          }
        } catch {
          // ignore
        }
      }
    }
  }

  // --- System Tray & Desktop Right-Click Context Menus ---
  private setupTray() {
    const trayIconPath = this.getAssetPath(process.platform === 'win32' ? 'icon.ico' : 'tray.png');
    const icon = nativeImage.createFromPath(trayIconPath);
    this.tray = new Tray(icon.isEmpty() ? nativeImage.createEmpty() : icon.resize({ width: 18, height: 18 }));
    this.tray.setToolTip('maki-land — Dynamic Island & Maki Companion');
    this.tray.on('click', () => {
      if (!this.isIslandVisible) {
        this.isIslandVisible = true;
        this.islandWin?.show();
      }
      this.setExpanded(!this.isExpanded);
    });
    this.rebuildTrayMenu();
  }

  private rebuildTrayMenu() {
    if (!this.tray) return;
    const menu = Menu.buildFromTemplate([
      {
        label: 'Tampilkan / Sembunyikan Island',
        click: () => {
          this.isIslandVisible = !this.isIslandVisible;
          if (this.isIslandVisible) this.islandWin?.show();
          else this.islandWin?.hide();
          this.scheduleBroadcast();
        },
      },
      {
        label: 'Buka / Tutup Mode Detail',
        click: () => this.setExpanded(!this.isExpanded),
      },
      {
        label: '🐾 Lepas / Panggil Maki di Desktop',
        click: () => {
          if (this.isOnDesktop) this.returnToNotch();
          else this.releaseToDesktop();
        },
      },
      { type: 'separator' },
      {
        label: '🪞 Buka Cermin (Mirror Kamera)',
        click: () => {
          this.isMirrorOpen = true;
          this.setExpanded(true);
          this.scheduleBroadcast();
        },
      },
      {
        label: '🎙️ Buka Perekam Suara',
        click: () => {
          this.selectedTab = 'Tray';
          this.setExpanded(true);
          this.scheduleBroadcast();
        },
      },
      { type: 'separator' },
      {
        label: 'Pilih Widget Berdasarkan Kategori',
        submenu: [
          {
            label: '🏠 Beranda & Maskot',
            submenu: [
              {
                label: '✨ Musik & Jadwal',
                click: () => {
                  this.selectedTab = 'maki-land';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
              {
                label: '🐾 Capy Habitat & AI',
                click: () => {
                  this.selectedTab = 'Capy';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
            ],
          },
          {
            label: '📁 Berkas & Media',
            submenu: [
              {
                label: '📥 Tray & Studio',
                click: () => {
                  this.selectedTab = 'Tray';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
            ],
          },
          {
            label: '📝 Catatan & Fokus',
            submenu: [
              {
                label: '📝 Catatan & To-Do',
                click: () => {
                  this.selectedTab = 'Notes';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
              {
                label: '⏳ Timer Fokus',
                click: () => {
                  this.selectedTab = 'Timer';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
              {
                label: '📋 Papan Klip',
                click: () => {
                  this.selectedTab = 'Clipboard';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
            ],
          },
          {
            label: '⚙️ Alat & Sistem',
            submenu: [
              {
                label: '📊 Monitor Sistem & Clean',
                click: () => {
                  this.selectedTab = 'System';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
              {
                label: '🚀 Peluncur Cepat',
                click: () => {
                  this.selectedTab = 'Launch';
                  this.setExpanded(true);
                  this.scheduleBroadcast();
                },
              },
            ],
          },
        ],
      },
      { type: 'separator' },
      {
        label: '⚡ Buka Otomatis saat Booting / Nyala',
        type: 'checkbox',
        checked: this.isLaunchAtLogin,
        click: () => this.applyAutoLaunchSetting(!this.isLaunchAtLogin),
      },
      {
        label: '❓ Panduan Penggunaan & Setup AI',
        click: () => {
          this.isShowingOnboarding = true;
          this.setExpanded(true);
          this.scheduleBroadcast();
        },
      },
      {
        label: '🔄 Periksa Pembaruan (GitHub)...',
        click: () => void this.checkForGitHubUpdates(true),
      },
      { type: 'separator' },
      {
        label: 'Keluar maki-land',
        click: () => app.quit(),
      },
    ]);
    this.tray.setContextMenu(menu);
  }

  private showDesktopRightClickMenu() {
    if (!this.desktopWin || this.desktopWin.isDestroyed()) return;
    const menu = Menu.buildFromTemplate([
      // 1. 💬 Tanya Maki AI
      {
        label: this.gemini.isDesktopChatOpen ? '💬 Tutup Obrolan Maki AI' : '💬 Tanya Jawab dengan Maki (AI)',
        click: () => {
          this.gemini.isDesktopChatOpen = !this.gemini.isDesktopChatOpen;
          this.syncDesktopWindowSizeForChat();
          this.scheduleBroadcast();
        },
      },
      {
        label: '📸 Tanya Maki soal Screenshot Terakhir',
        click: () => {
          this.gemini.attachLatestScreenshotOrClipboard();
          this.gemini.isDesktopChatOpen = true;
          this.syncDesktopWindowSizeForChat();
          this.scheduleBroadcast();
        },
      },
      { type: 'separator' },

      // 2. 🪞 Alat Cepat (Quick Tools)
      {
        label: '🪞 Buka Cermin (Mirror Kamera)',
        click: () => {
          this.isMirrorOpen = true;
          this.setExpanded(true);
          this.scheduleBroadcast();
        },
      },
      {
        label: '🎙️ Buka Perekam Suara',
        click: () => {
          this.selectedTab = 'Tray';
          this.setExpanded(true);
          this.scheduleBroadcast();
        },
      },
      {
        label: '📥 Masukkan Screenshot ke Tray',
        click: async () => {
          const item = await this.studio.grabClipboardOrRecentScreenshot();
          if (item) {
            this.selectedTab = 'Tray';
            this.setExpanded(true);
            this.emitAllBubbles('udah masuk Tray ya, tinggal ambil', true);
          } else {
            this.emitAllBubbles('belum nemu screenshot baru nih..', true);
          }
        },
      },
      {
        label: '🧹 Bersihkan Cache Aman (Maki Clean)',
        click: () => void this.cleanCacheInteractive(),
      },
      { type: 'separator' },

      // 3. 🎪 Interaksi & Atraksi Maskot
      {
        label: '🍉 Kasih Makan',
        submenu: CAPY_FOODS.map((f) => ({
          label: `${f.emoji} Kasih ${f.id}`,
          click: () => this.feed(f.id),
        })),
      },
      {
        label: `🍊 Tumpuk Jeruk di Kepala (${this.orangesOnHead}/3)`,
        click: () => this.cycleOranges(),
      },
      {
        label: '♨️ Berendam Air Panas Onsen',
        type: 'checkbox' as const,
        checked: this.isOnsenMode,
        click: () => this.toggleOnsen(),
      },
      {
        label: '🎪 Atraksi Acak',
        click: () => this.performRandomIdleActivity(false),
      },
      {
        label: '🎭 Pilih Atraksi Spesifik',
        submenu: [
          { label: '🍊 Sirkus 3 Jeruk', click: () => this.triggerSpecificActivity('jugglingOranges', 'satu.. dua.. tiga..', 8000) },
          { label: '💻 Ngoding Laptop Mini', click: () => this.triggerSpecificActivity('typingLaptop', 'ikut ngetik ah..', 7500) },
          { label: '🍵 Nyeruput Matcha Hangat', click: () => this.triggerSpecificActivity('sippingTea', 'anget tehnya..', 7000) },
          { label: '🦋 Kejar Kupu-Kupu', click: () => this.triggerSpecificActivity('butterflyChase', 'eh ada kupu-kupu', 7500) },
          { label: '🫧 Tiup Gelembung Sabun', click: () => this.triggerSpecificActivity('blowingBubbles', 'fuuhh..', 7000) },
          { label: '📖 Baca Buku', click: () => this.triggerSpecificActivity('readingBook', 'baca bentar..', 7000) },
          { label: '💪 Peregangan Badan', click: () => this.triggerSpecificActivity('stretching', 'pegel duduk terus..', 6000) },
        ],
      },
      {
        label: this.isChasingCursor ? '⏹️ Berhenti Kejar Kursor' : '🐾 Main Kejar Kursor',
        click: () => {
          if (this.isChasingCursor) this.stopChaseCursor(false);
          else this.startChaseCursor();
        },
      },
      {
        label: '👋 Elus Maki',
        click: () => this.interactInTab('Capy', true),
      },
      { type: 'separator' },

      // 4. 🎨 Tampilan & Model
      {
        label: `🎨 Model Tampilan: ${this.mascotModel === 'plushie' ? '🧸 Boneka' : '🐾 Klasik'}`,
        submenu: [
          {
            label: '🐾 Maki Klasik',
            type: 'checkbox' as const,
            checked: this.mascotModel === 'classic',
            click: () => {
              this.mascotModel = 'classic';
              this.savePersisted();
              this.showDesktopBubble('kembali ke bulu cokelat klasik 🐾', 3000);
              this.scheduleBroadcast();
            },
          },
          {
            label: "🧸 Maki Boneka (Kaos 'maki')",
            type: 'checkbox' as const,
            checked: this.mascotModel === 'plushie',
            click: () => {
              this.mascotModel = 'plushie';
              this.savePersisted();
              this.showDesktopBubble("pakai kaos 'maki' kesayangan 🧸✨", 3000);
              this.scheduleBroadcast();
            },
          },
        ],
      },
      { type: 'separator' },

      // 5. 🚶 Navigasi Desktop
      {
        label: '🚶 Bebas Jalan-Jalan di Desktop',
        type: 'checkbox',
        checked: this.desktopRoamEnabled,
        click: () => {
          this.desktopRoamEnabled = !this.desktopRoamEnabled;
          this.savePersisted();
          if (!this.desktopRoamEnabled) {
            this.walkTarget = null;
            this.showDesktopBubble('oke duduk sini aja', 2200);
          } else {
            this.showDesktopBubble('jalan-jalan lagi ah', 2200);
            this.startAutonomousStroll();
          }
          this.scheduleBroadcast();
        },
      },
      {
        label: '🏠 Jalan Pulang ke Notch',
        click: () => this.returnToNotch(),
      },
      { type: 'separator' },

      // 6. ⚙️ Pengaturan & Bantuan
      {
        label: '⚡ Buka Otomatis saat Booting / Nyala',
        type: 'checkbox',
        checked: this.isLaunchAtLogin,
        click: () => {
          this.applyAutoLaunchSetting(!this.isLaunchAtLogin);
          this.showDesktopBubble(
            `autorun booting ${this.isLaunchAtLogin ? 'aktif ⚡' : 'dimatikan'}`,
            2800
          );
        },
      },
      {
        label: '❓ Panduan Penggunaan & Setup AI',
        click: () => {
          this.isShowingOnboarding = true;
          this.setExpanded(true);
          this.scheduleBroadcast();
        },
      },
      {
        label: '🔄 Periksa Pembaruan (GitHub)...',
        click: () => void this.checkForGitHubUpdates(true),
      },
    ]);
    menu.popup({ window: this.desktopWin });
  }

  // --- Background Loops (Clipboard, System/SMTC, Timer, Autonomous Life, 30/60Hz Motion) ---
  private startBackgroundLoops() {
    // 1. 30 Hz Click-through + Gaze
    setInterval(() => this.updateClickThroughAndGaze(), 33);

    // 2. 60 Hz Desktop Maki Motion & Throw Physics
    let lastTick = Date.now();
    setInterval(() => {
      const now = Date.now();
      const dt = Math.min(0.05, Math.max(0.005, (now - lastTick) / 1000));
      lastTick = now;
      this.tickDesktopMotion(dt);
    }, 16);

    // 3. Windows CPU/RAM/Battery & SMTC Media Polling (every 2.5s)
    void pollWindowsStatusOnce().then(() => this.scheduleBroadcast());
    setInterval(() => {
      void pollWindowsStatusOnce().then(() => this.scheduleBroadcast());
    }, 2500);

    // 4. 24/7 Clipboard Monitor (every 700ms)
    setInterval(() => {
      this.pollClipboard();
    }, 700);

    // 5. Focus Timer 1s Countdown
    setInterval(() => {
      if (this.timerRunning && this.timerRemaining > 0) {
        this.timerRemaining -= 1;
        if (this.timerRemaining <= 0) {
          this.timerRemaining = 0;
          this.timerRunning = false;
          this.timerAlert = true;
          this.emitAllBubbles('waktunya selesai! istirahat bentar yuk 🎉', this.isOnDesktop);
        }
        this.scheduleBroadcast();
      }
    }, 1000);

    // 6. Autonomous Living Loop (every 6s)
    setInterval(() => {
      this.tickAutonomousLife();
    }, 6000);

    // 7. Periodic Google / Outlook Calendar (.ics) Re-sync (every 30 minutes)
    setInterval(() => {
      if (this.googleICSUrl) {
        void this.syncGoogleICS(this.googleICSUrl);
      }
    }, 30 * 60 * 1000);

    // 8. Re-assert topmost Z-order above all active applications (like Google Chrome, Edge, VS Code)
    setInterval(() => {
      if (this.isOnDesktop && this.desktopWin && !this.desktopWin.isDestroyed()) {
        this.desktopWin.setAlwaysOnTop(true, 'screen-saver');
        this.desktopWin.moveTop();
      }
      if (this.companionWin && !this.companionWin.isDestroyed()) {
        this.companionWin.setAlwaysOnTop(true, 'screen-saver');
        this.companionWin.moveTop();
      }
      if (this.islandWin && !this.islandWin.isDestroyed()) {
        this.islandWin.setAlwaysOnTop(true, 'screen-saver');
        this.islandWin.moveTop();
      }
    }, 2000);
  }

  private pollClipboard() {
    try {
      const txt = clipboard.readText().trim();
      if (txt && txt !== this.lastClipText) {
        this.lastClipText = txt;
        this.clipboardHistory = [
          {
            id: crypto.randomUUID(),
            kind: 'text' as const,
            text: txt.slice(0, 2000),
            timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
          },
          ...this.clipboardHistory.filter((c) => c.text !== txt),
        ].slice(0, 35);
        this.scheduleBroadcast();
        return;
      }

      const img = clipboard.readImage();
      if (!img.isEmpty()) {
        const sz = img.getSize();
        if (sz.width > 8 && sz.height > 8) {
          const thumb = img.resize({ width: 96 }).toDataURL();
          const hash = `${sz.width}x${sz.height}:${thumb.slice(-48)}`;
          if (hash !== this.lastClipImgHash) {
            this.lastClipImgHash = hash;
            this.clipboardHistory = [
              {
                id: crypto.randomUUID(),
                kind: 'image' as const,
                text: `Gambar Clipboard (${sz.width}×${sz.height})`,
                previewDataUrl: thumb,
                timestamp: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
              },
              ...this.clipboardHistory,
            ].slice(0, 35);
            this.scheduleBroadcast();
          }
        }
      }
    } catch {
      // ignore transient clipboard lock
    }
  }

  private tickAutonomousLife() {
    if (
      this.isDraggingOnDesktop ||
      this.isHeldForDrop ||
      this.isChasingCursor ||
      this.isReturningToNotch ||
      this.gemini.isThinking ||
      this.gemini.isDesktopChatOpen
    ) {
      return;
    }
    if (isIdleShowActivity(this.currentAction) || this.currentAction === 'sleeping') return;
    if (
      this.currentAction === 'happyPet' ||
      this.currentAction === 'ticklish' ||
      this.currentAction === 'dizzy' ||
      this.currentAction === 'brushed' ||
      this.currentAction === 'eating' ||
      this.currentAction === 'swallowing'
    ) {
      return;
    }

    if (this.isOnsenMode && !this.isOnDesktop) {
      this.posX = 0;
      this.currentAction = 'chill';
      return;
    }

    const track = getCurrentTrackSnapshot();

    if (this.isOnDesktop) {
      if (this.walkTarget) return;
      const roll = Math.floor(Math.random() * 12);
      if (this.desktopRoamEnabled && !this.isOnsenMode && roll < 5) {
        this.startAutonomousStroll();
      } else if (roll < 10 && !this.isOnsenMode) {
        this.performRandomIdleActivity(true);
      } else if (roll === 10 && !track.isPlaying) {
        this.currentAction = 'sleeping';
        if (Math.random() < 0.5) this.showDesktopBubble('ngantuk dikit..', 2500);
        this.scheduleActionReset(9000);
        this.scheduleBroadcast();
      }
      return;
    }

    // Inside Habitat / Notch
    const roll = Math.floor(Math.random() * 10);
    if (roll < 3) {
      const nextX = Math.round((Math.random() * 92 - 46) * 10) / 10;
      this.facingRight = nextX >= this.posX;
      this.posX = nextX;
      this.currentAction = 'walking';
      this.scheduleActionReset(1000);
      this.scheduleBroadcast();
    } else if (roll < 7) {
      this.performRandomIdleActivity(true);
    } else if (roll === 9 && !track.isPlaying && !this.timerRunning) {
      this.currentAction = 'sleeping';
      this.scheduleActionReset(7000);
      this.scheduleBroadcast();
    }
  }

  // --- IPC Bridge ---
  private setupIPC() {
    ipcMain.handle('maki:get-state', () => this.buildStateSnapshot());

    ipcMain.on('maki:compact-hover', (_ev, hovering: boolean) => {
      if (hovering && Date.now() < this.collapseCooldownUntil) return;
      this.isCompactHovering = Boolean(hovering);
    });

    ipcMain.on('maki:drop-hold', (_ev, holding: boolean) => {
      if (holding) {
        this.holdForDrop(4000);
        this.isMouthOpenForDrop = true;
      } else {
        this.dropHoldUntil = Date.now() + 700;
        this.isMouthOpenForDrop = false;
      }
      this.scheduleBroadcast();
    });

    ipcMain.on('maki:prepare-drag', () => {
      this.isNativeFileDragging = true;
      if (this.islandWin && !this.islandWin.isDestroyed()) {
        this.islandWin.setIgnoreMouseEvents(false);
      }
    });

    ipcMain.on('maki:start-drag', (ev, filePath: string) => {
      if (!filePath) return;
      const fullPath = path.win32 ? path.win32.normalize(path.resolve(filePath)) : path.resolve(filePath);
      if (!fs.existsSync(fullPath)) return;

      this.isNativeFileDragging = true;
      if (this.islandWin && !this.islandWin.isDestroyed()) {
        this.islandWin.setIgnoreMouseEvents(false);
      }

      let dragIcon: Electron.NativeImage | string = '';
      try {
        const iconPath = this.getAssetPath('tray.png');
        if (fs.existsSync(iconPath)) {
          const buf = fs.readFileSync(iconPath);
          const img = nativeImage.createFromBuffer(buf);
          if (!img.isEmpty()) {
            dragIcon = img.resize({ width: 32, height: 32 });
          }
        }
      } catch (err) {
        console.warn('[Drag] Failed loading tray.png buffer:', err);
      }

      if (!dragIcon || (typeof dragIcon !== 'string' && dragIcon.isEmpty())) {
        try {
          const fallbackPath = this.getAssetPath('icon.png');
          if (fs.existsSync(fallbackPath)) {
            const buf = fs.readFileSync(fallbackPath);
            const img = nativeImage.createFromBuffer(buf);
            if (!img.isEmpty()) {
              dragIcon = img.resize({ width: 32, height: 32 });
            }
          }
        } catch {}
      }

      if (!dragIcon || (typeof dragIcon !== 'string' && dragIcon.isEmpty())) {
        dragIcon = nativeImage.createFromBitmap(Buffer.alloc(32 * 32 * 4, 255), { width: 32, height: 32 });
      }

      try {
        ev.sender.startDrag({
          file: fullPath,
          icon: dragIcon,
        });
      } catch (err) {
        console.error('[maki:start-drag] Error invoking startDrag:', err);
      } finally {
        setTimeout(() => {
          this.isNativeFileDragging = false;
        }, 1500);
      }
    });

    ipcMain.on('maki:end-drag', () => {
      this.isNativeFileDragging = false;
    });

    ipcMain.handle(
      'maki:save-voice-recording',
      async (_ev, payload: { base64Data: string; durationSec: number; mimeType?: string }) => {
        try {
          if (!payload?.base64Data) {
            return { success: false, error: 'Data rekaman kosong' };
          }
          const docs = app.getPath('documents') || os.homedir();
          const audioDir = path.join(docs, 'maki-land Audio');
          fs.mkdirSync(audioDir, { recursive: true });

          const now = new Date();
          const pad = (n: number) => String(n).padStart(2, '0');
          const timestamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
          const isWebm = (payload.mimeType || '').includes('webm');
          const ext = isWebm ? 'webm' : 'wav';
          const fileName = `Rekaman_${timestamp}.${ext}`;
          const targetPath = path.join(audioDir, fileName);

          const buf = Buffer.from(payload.base64Data, 'base64');
          fs.writeFileSync(targetPath, buf);

          await this.studio.addFilePaths([targetPath], false);
          if (process.platform === 'win32') {
            await copyFileToWindowsClipboard(targetPath);
          }

          const durSec = Math.round(payload.durationSec || 0);
          this.studio.showBanner(`🎙️ Rekaman "${fileName}" (${durSec}dtk) tersimpan di Tray & Clipboard! 📋`);
          if (this.isOnDesktop) {
            this.showDesktopBubble(`🎙️ Rekaman suaramu masuk Tray! Siap dipaste (Ctrl+V) atau ditarik ya~ 🐾`, 5500);
          }
          this.scheduleBroadcast();

          return { success: true, filePath: targetPath, fileName };
        } catch (err: any) {
          console.error('[maki:save-voice-recording] Error saving recording:', err);
          return { success: false, error: err?.message || String(err) };
        }
      }
    );

    ipcMain.handle(
      'maki:save-camera-photo',
      async (_ev, payload: { base64Data: string }) => {
        try {
          if (!payload?.base64Data) {
            return { success: false, error: 'Data foto kosong' };
          }
          const docs = app.getPath('documents') || os.homedir();
          const photoDir = path.join(docs, 'maki-land Photos');
          fs.mkdirSync(photoDir, { recursive: true });

          const now = new Date();
          const pad = (n: number) => String(n).padStart(2, '0');
          const timestamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
          const fileName = `Foto_${timestamp}.png`;
          const targetPath = path.join(photoDir, fileName);

          const buf = Buffer.from(payload.base64Data, 'base64');
          fs.writeFileSync(targetPath, buf);

          await this.studio.addFilePaths([targetPath], false);
          if (process.platform === 'win32') {
            await copyFileToWindowsClipboard(targetPath);
          }

          this.studio.showBanner(`📸 Foto "${fileName}" tersimpan di Tray & Clipboard! 📋`);
          if (this.isOnDesktop) {
            this.showDesktopBubble(`📸 Fotonya cakep! Sudah masuk Tray ya~ 🐾`, 5000);
          }
          this.scheduleBroadcast();

          return { success: true, filePath: targetPath, fileName };
        } catch (err: any) {
          console.error('[maki:save-camera-photo] Error saving photo:', err);
          return { success: false, error: err?.message || String(err) };
        }
      }
    );

    ipcMain.on('maki:desktop-context-menu', () => {
      this.showDesktopRightClickMenu();
    });

    // Desktop Maki Drag & Throw IPC
    ipcMain.on('maki:desktop-drag-start', (_ev, { screenX, screenY }: { screenX: number; screenY: number }) => {
      if (!this.desktopWin || this.desktopWin.isDestroyed()) return;
      if (this.isReturningToNotch) {
        this.homePhase = { kind: 'none' };
        this.isReturningToNotch = false;
        this.notchClimbProgress = 0;
      }
      this.walkTarget = null;
      this.throwVel = { x: 0, y: 0 };
      const b = this.desktopWin.getBounds();
      this.dragStartMouse = { x: screenX, y: screenY };
      this.dragStartOrigin = { x: b.x, y: b.y };
      this.lastDragMouse = { x: screenX, y: screenY };
      this.lastDragTime = Date.now();
      this.dragVelocity = { x: 0, y: 0 };
      this.isWindowDragActive = false;
    });

    ipcMain.on('maki:desktop-drag-move', (_ev, { screenX, screenY }: { screenX: number; screenY: number }) => {
      if (!this.desktopWin || this.desktopWin.isDestroyed()) return;
      const now = Date.now();
      const dt = Math.max(0.005, (now - this.lastDragTime) / 1000);
      this.dragVelocity = {
        x: (screenX - this.lastDragMouse.x) / dt,
        y: (screenY - this.lastDragMouse.y) / dt,
      };
      this.lastDragMouse = { x: screenX, y: screenY };
      this.lastDragTime = now;

      const dx = screenX - this.dragStartMouse.x;
      const dy = screenY - this.dragStartMouse.y;
      if (!this.isWindowDragActive && Math.hypot(dx, dy) > 5) {
        this.isWindowDragActive = true;
        this.isDraggingOnDesktop = true;
        this.isChasingCursor = false;
        this.showDesktopBubble('eh mau dibawa kemana..', 2000);
      }
      if (this.isWindowDragActive) {
        const cursor = { x: screenX, y: screenY };
        const b = this.desktopWin.getBounds();
        const primary = screen.getPrimaryDisplay();
        const targetDisplay = screen.getDisplayNearestPoint(cursor);
        const nearTopNotch =
          targetDisplay.id === primary.id &&
          screenY <= primary.bounds.y + 62 &&
          Math.abs(screenX - (primary.bounds.x + primary.bounds.width / 2)) < 200;

        // Smooth multi-monitor span across all displays!
        const displays = screen.getAllDisplays();
        const minX = Math.min(...displays.map((d) => d.bounds.x)) - b.width + 48;
        const maxX = Math.max(...displays.map((d) => d.bounds.x + d.bounds.width)) - 48;
        const minY = Math.min(...displays.map((d) => d.bounds.y)) - b.height + 48;
        const maxY = Math.max(...displays.map((d) => d.bounds.y + d.bounds.height));

        const nx = Math.max(minX, Math.min(maxX, this.dragStartOrigin.x + dx));
        const ny = nearTopNotch
          ? this.dragStartOrigin.y + dy
          : Math.max(minY, Math.min(maxY, this.dragStartOrigin.y + dy));
        this.desktopWin.setPosition(Math.round(nx), Math.round(ny));
      }
    });

    ipcMain.on('maki:desktop-drag-end', (_ev, { screenX, screenY }: { screenX: number; screenY: number }) => {
      if (!this.desktopWin || this.desktopWin.isDestroyed()) return;
      if (this.isWindowDragActive) {
        this.isWindowDragActive = false;
        this.isDraggingOnDesktop = false;
        const cursor = { x: screenX, y: screenY };
        const primary = screen.getPrimaryDisplay();
        const targetDisplay = screen.getDisplayNearestPoint(cursor);
        if (
          targetDisplay.id === primary.id &&
          screenY <= primary.bounds.y + 62 &&
          Math.abs(screenX - (primary.bounds.x + primary.bounds.width / 2)) < 200
        ) {
          this.returnToNotch();
          return;
        }
        const spd = Math.hypot(this.dragVelocity.x, this.dragVelocity.y);
        if (spd > 200) {
          this.throwVel = {
            x: Math.max(-1400, Math.min(1400, this.dragVelocity.x)),
            y: Math.max(-1400, Math.min(1400, this.dragVelocity.y)),
          };
        } else {
          // Snap neatly inside targetDisplay.workArea
          const b = this.desktopWin.getBounds();
          const wa = targetDisplay.workArea;
          const safeX = Math.max(wa.x + 4, Math.min(wa.x + wa.width - b.width - 4, b.x));
          const safeY = Math.max(wa.y + 4, Math.min(wa.y + wa.height - b.height - 4, b.y));
          this.desktopWin.setPosition(safeX, safeY);
          this.desktopOrigin = { x: safeX, y: safeY };
          this.savePersisted();
          this.registerSquish();
          this.showDesktopBubble('sip, duduk sini aja', 2000);
        }
        this.scheduleBroadcast();
      }
    });

    // ── Companion Moko IPC ────────────────────────────────────────────────
    ipcMain.on('maki:companion-drag-start', (_ev, { screenX, screenY }: { screenX: number; screenY: number }) => {
      if (!this.companionWin || this.companionWin.isDestroyed()) return;
      this.companionWin.setIgnoreMouseEvents(false);
      this.stopCompanionWalk();
    });

    ipcMain.on('maki:companion-drag-move', (_ev, { screenX, screenY }: { screenX: number; screenY: number }) => {
      if (!this.companionWin || this.companionWin.isDestroyed()) return;
      const b = this.companionWin.getBounds();
      const allDisplays = screen.getAllDisplays();
      const minX = Math.min(...allDisplays.map(d => d.bounds.x)) - b.width + 48;
      const maxX = Math.max(...allDisplays.map(d => d.bounds.x + d.bounds.width)) - 48;
      const minY = Math.min(...allDisplays.map(d => d.bounds.y));
      const maxY = Math.max(...allDisplays.map(d => d.bounds.y + d.bounds.height));
      const clampedX = Math.max(minX, Math.min(maxX, screenX - b.width / 2));
      const clampedY = Math.max(minY, Math.min(maxY, screenY - b.height / 2));
      this.companionWin.setPosition(Math.round(clampedX), Math.round(clampedY));
    });

    ipcMain.on('maki:companion-drag-end', (_ev, { screenX, screenY }: { screenX: number; screenY: number }) => {
      if (!this.companionWin || this.companionWin.isDestroyed()) return;
      const cursor = { x: screenX, y: screenY };
      const targetDisplay = screen.getDisplayNearestPoint(cursor);
      const b = this.companionWin.getBounds();
      const wa = targetDisplay.workArea;
      const safeX = Math.max(wa.x + 4, Math.min(wa.x + wa.width - b.width - 4, b.x));
      const safeY = Math.max(wa.y + 4, Math.min(wa.y + wa.height - b.height - 4, b.y));
      this.companionWin.setPosition(safeX, safeY);
      this.companionOrigin = { x: safeX, y: safeY };
      this.companionWin.setIgnoreMouseEvents(true, { forward: true });
      this.showCompanionBubble('moko duduk sini ya~', 2000);
      // Check proximity with Maki for high-five!
      if (this.desktopWin && !this.desktopWin.isDestroyed()) {
        const db = this.desktopWin.getBounds();
        const dist = Math.hypot(b.x + b.width / 2 - (db.x + db.width / 2), b.y + b.height / 2 - (db.y + db.height / 2));
        if (dist < 150 && targetDisplay.id === screen.getDisplayNearestPoint({ x: db.x, y: db.y }).id) {
          setTimeout(() => {
            this.showCompanionBubble('🐾 High-Five Maki! Sahabat selamanya! ❤️', 3000);
            this.showDesktopBubble('🐾 Tos Moko! Asik banget kumpul bareng!', 3000);
            this.scheduleBroadcast();
          }, 300);
        }
      }
      this.scheduleBroadcast();
    });

    ipcMain.on('maki:companion-context-menu', () => {
      const menu = Menu.buildFromTemplate([
        { label: '💬 Ajak Ngobrol Maki', click: () => { void this.handleAction('companionBanter', {}); } },
        { label: '🍊 Lempar Jeruk ke Maki', click: () => { void this.handleAction('companionOrangeToss', {}); } },
        { label: '♨️ ' + (this.companionIsOnsen ? 'Selesai Berendam' : 'Berendam Onsen'), click: () => { void this.handleAction('companionToggleOnsen', {}); } },
        { label: '🐾 Tos / High-Five dengan Maki', click: () => { void this.handleAction('companionHighFive', {}); } },
      ]);
      menu.popup();
    });

    ipcMain.handle('maki:dispatch', async (_ev, action: string, payload?: Record<string, unknown>) => {
      await this.handleAction(action, payload || {});
      return this.buildStateSnapshot();
    });
  }

  private async handleAction(action: string, p: Record<string, unknown>) {
    switch (action) {
      case 'expand':
        this.setExpanded(Boolean(p.expanded));
        break;
      case 'selectTab':
        this.selectedTab = p.tab as IslandTab;
        if (!this.isExpanded) this.setExpanded(true);
        break;
      case 'togglePin':
        this.isPinned = !this.isPinned;
        break;
      case 'toggleMicMute':
        this.isMicMuted = await toggleWindowsMicMute(!this.isMicMuted);
        break;
      case 'toggleMirror':
        this.isMirrorOpen = !this.isMirrorOpen;
        if (this.isMirrorOpen && !this.isExpanded) {
          this.setExpanded(true);
        }
        break;
      case 'closeMirror':
        this.isMirrorOpen = false;
        break;
      case 'toggleAutoLaunch':
        this.applyAutoLaunchSetting(!this.isLaunchAtLogin);
        break;

      // Capybara actions
      case 'pet':
        this.interactInTab((p.tab as IslandTab) || this.selectedTab, Boolean(p.fromDesktop));
        break;
      case 'strokeFur': {
        const now = Date.now();
        this.currentAction = 'brushed';
        if (now - this.lastStrokeSoundTime > 900) {
          this.lastStrokeSoundTime = now;
          this.mood = Math.min(100, this.mood + 3);
          this.xp += 2;
          this.registerSquish();
          this.emitAllBubbles('wah enak disisir..', this.isOnDesktop);
          this.savePersisted();
        }
        this.scheduleActionReset(1400);
        break;
      }
      case 'randomTrick':
        this.performRandomIdleActivity(false);
        break;
      case 'feed':
        this.feed((p.food as CapyFood) || 'Jeruk');
        break;
      case 'cycleOranges':
        this.cycleOranges();
        break;
      case 'toggleOnsen':
        this.toggleOnsen();
        break;
      case 'toggleDesktop':
        if (this.isOnDesktop) this.returnToNotch();
        else this.releaseToDesktop();
        break;
      case 'releaseToDesktop':
        this.releaseToDesktop();
        break;
      case 'returnToNotch':
        this.returnToNotch();
        break;
      case 'toggleDesktopRoam':
        this.desktopRoamEnabled = !this.desktopRoamEnabled;
        this.savePersisted();
        if (!this.desktopRoamEnabled) {
          this.walkTarget = null;
          this.showDesktopBubble('oke duduk sini aja', 2000);
        } else {
          this.showDesktopBubble('jalan-jalan lagi ah', 2000);
          this.startAutonomousStroll();
        }
        break;

      // ── Companion Moko actions ────────────────────────────────────────
      case 'companionPet':
        this.showCompanionBubble(['Moko senang dielus! ✨', 'Hehe geli kak~', 'Semangat kerjanya ya bos!'].at(Math.floor(Math.random() * 3))!, 2500);
        break;
      case 'companionBanter': {
        const pair = this.banterPairs[this.banterIndex % this.banterPairs.length];
        this.banterIndex++;
        this.showDesktopBubble(pair.maki, 3500);
        setTimeout(() => { this.showCompanionBubble(pair.moko, 3800); this.scheduleBroadcast(); }, 2000);
        break;
      }
      case 'companionOrangeToss':
        this.showCompanionBubble('Maki, tangkap jeruk ini! 🍊💨', 2500);
        setTimeout(() => {
          this.orangesOnHead = Math.min(3, this.orangesOnHead + 1);
          this.registerSquish();
          this.showDesktopBubble('Hup! Ketangkap! Seger banget, makasih Moko! 😋', 3000);
          this.scheduleBroadcast();
        }, 1200);
        break;
      case 'companionToggleOnsen':
        this.companionIsOnsen = !this.companionIsOnsen;
        this.showCompanionBubble(this.companionIsOnsen ? 'Wah segernya air hangat onsen~ ♨️' : 'Selesai berendam, badan enteng!', 2800);
        break;
      case 'companionToggleRoam':
        this.companionRoamEnabled = !this.companionRoamEnabled;
        if (this.companionRoamEnabled) {
          this.showCompanionBubble('moko mau jalan-jalan!', 2000);
          this.startCompanionStroll();
        } else {
          this.stopCompanionWalk();
          this.showCompanionBubble('moko diam di sini ya', 2000);
        }
        break;
      case 'companionHighFive':
        this.showCompanionBubble('🐾 High-Five Maki! Sahabat selamanya! ❤️', 3200);
        this.showDesktopBubble('🐾 Tos Moko! Asik banget kumpul bareng!', 3200);
        this.registerSquish();
        break;
      case 'toggleChaseCursor':
        if (this.isChasingCursor) this.stopChaseCursor(false);
        else this.startChaseCursor();
        break;
      case 'toggleMascotModel':
        this.mascotModel = this.mascotModel === 'classic' ? 'plushie' : 'classic';
        this.savePersisted();
        this.emitAllBubbles(
          this.mascotModel === 'plushie'
            ? "Aku pakai kaos 'maki' kesayangan! 🧸"
            : 'Kembali ke bulu cokelat klasik! 🐾',
          this.isOnDesktop
        );
        this.rebuildTrayMenu();
        break;
      case 'toggleShowInCompact':
        this.showInCompactNotch = !this.showInCompactNotch;
        this.savePersisted();
        break;

      // Media & Calendar
      case 'mediaControl':
        await sendWindowsMediaControl(p.cmd as 'playPause' | 'next' | 'prev');
        break;
      case 'toggleCalendarSettings':
        this.isShowingCalendarSettings = !this.isShowingCalendarSettings;
        break;
      case 'syncGoogleICS':
        await this.syncGoogleICS(String(p.url || ''));
        break;
      case 'addCalendarEvent': {
        const title = String(p.title || '').trim();
        const dateISO = String(p.dateISO || new Date().toISOString().slice(0, 10));
        const timeLabel = String(p.timeLabel || '').trim() || 'Seharian';
        if (title) {
          this.localCalendarEvents.push({
            id: crypto.randomUUID(),
            title,
            dateISO,
            timeLabel,
            isAllDay: timeLabel === 'Seharian',
            source: 'Local',
            colorHex: '#ffa94d',
          });
          this.savePersisted();
        }
        break;
      }
      case 'deleteCalendarEvent':
        this.localCalendarEvents = this.localCalendarEvents.filter((e) => e.id !== String(p.id));
        this.savePersisted();
        break;

      // Notes & To-Do
      case 'setScratchpad':
        this.scratchpadText = String(p.text ?? '');
        this.savePersisted();
        break;
      case 'addTodo': {
        const raw = String(p.title || '').trim();
        if (raw) {
          for (const line of raw.split(/\r?\n/)) {
            const clean = line.replace(/^([-*•]|\[\s?\])\s*/, '').trim();
            if (clean) {
              this.todos.push({ id: crypto.randomUUID(), title: clean, isDone: false });
            }
          }
          this.savePersisted();
        }
        break;
      }
      case 'toggleTodo': {
        const t = this.todos.find((x) => x.id === String(p.id));
        if (t) {
          t.isDone = !t.isDone;
          if (t.isDone) this.showContextualTip('satu tugas beres nih');
          this.savePersisted();
        }
        break;
      }
      case 'toggleTodoIndex': {
        const idx = Number(p.index);
        if (idx >= 0 && idx < this.todos.length) {
          this.todos[idx].isDone = !this.todos[idx].isDone;
          this.showNotesToast(`${this.todos[idx].isDone ? '✓ Selesai' : '↺ Belum'}: #${idx + 1}`);
          this.savePersisted();
        }
        break;
      }
      case 'deleteTodo':
        this.todos = this.todos.filter((x) => x.id !== String(p.id));
        this.savePersisted();
        break;
      case 'clearCompletedTodos':
        this.todos = this.todos.filter((x) => !x.isDone);
        this.showNotesToast('Tugas selesai dibersihkan');
        this.savePersisted();
        break;

      // Quick Launcher
      case 'launchItem': {
        const item = this.launcherItems.find((x) => x.id === String(p.id));
        if (item) {
          this.showContextualTip(`buka ${item.name.toLowerCase()} ya`);
          if (item.isWeb) {
            const u = item.urlOrPath.includes('://') ? item.urlOrPath : `https://${item.urlOrPath}`;
            void shell.openExternal(u);
          } else {
            void shell.openPath(item.urlOrPath);
          }
        }
        break;
      }
      case 'pickLauncherApp': {
        this.isModalOpen = true;
        try {
          const res = await dialog.showOpenDialog(this.islandWin || BrowserWindow.getAllWindows()[0], {
            title: 'Pilih Aplikasi (.exe / .lnk) atau Folder untuk Quick Launch',
            properties: ['openFile', 'multiSelections'],
          });
          if (!res.canceled && res.filePaths.length > 0) {
            for (const fp of res.filePaths) {
              if (this.launcherItems.some((x) => x.urlOrPath === fp)) continue;
              const name = path.basename(fp, path.extname(fp));
              let iconDataUrl: string | undefined;
              try {
                const ic = await app.getFileIcon(fp, { size: 'normal' });
                if (!ic.isEmpty()) iconDataUrl = ic.toDataURL();
              } catch {
                // ignore
              }
              this.launcherItems.push({
                id: crypto.randomUUID(),
                name,
                urlOrPath: fp,
                iconEmoji: '🚀',
                iconDataUrl,
                isWeb: false,
              });
            }
            this.savePersisted();
          }
        } finally {
          this.isModalOpen = false;
        }
        break;
      }
      case 'addLauncherUrl': {
        const name = String(p.name || '').trim();
        const url = String(p.url || '').trim();
        if (name && url) {
          this.launcherItems.push({
            id: crypto.randomUUID(),
            name,
            urlOrPath: url,
            iconEmoji: '🌐',
            isWeb: true,
          });
          this.savePersisted();
        }
        break;
      }
      case 'removeLauncherItem':
        this.launcherItems = this.launcherItems.filter((x) => x.id !== String(p.id));
        this.savePersisted();
        break;

      // Tray & PDF/Image Studio
      case 'dropFiles': {
        const paths = (p.paths as string[]) || [];
        if (
          (this.gemini.isDesktopChatOpen || (this.isExpanded && this.selectedTab === 'Capy' && this.gemini.isNotchChatMode)) &&
          paths.length > 0 &&
          this.gemini.attachImageFromPath(paths[0])
        ) {
          this.registerSquish();
          break;
        }
        await this.swallowFilesIntoTray(paths);
        break;
      }
      case 'grabScreenshot': {
        const grabbed = await this.studio.grabClipboardOrRecentScreenshot();
        if (grabbed) {
          this.registerSquish();
          this.currentAction = 'swallowing';
          this.selectedTab = 'Tray';
          this.setExpanded(true);
          this.emitAllBubbles('udah masuk Tray ya, tinggal ambil', this.isOnDesktop);
          this.scheduleActionReset(1800);
        } else {
          this.emitAllBubbles('belum nemu screenshot baru nih..', this.isOnDesktop);
        }
        break;
      }
      case 'pickTrayFiles':
        this.isModalOpen = true;
        try {
          await this.studio.pickFilesDialog(this.islandWin);
        } finally {
          this.isModalOpen = false;
        }
        break;
      case 'copyTrayItem':
        await this.studio.copyItemToClipboard(String(p.id));
        break;
      case 'openStudioItem':
        this.studio.setActiveStudioItem(p.id ? String(p.id) : null);
        break;
      case 'removeTrayItem':
        this.studio.removeItem(String(p.id));
        break;
      case 'clearTray':
        this.studio.clearAll();
        break;
      case 'revealTrayItem':
        this.studio.revealItem(String(p.id));
        break;
      case 'renameTrayItem':
        this.studio.renameItem(String(p.id), String(p.newName || ''));
        break;
      case 'mergeTrayPdf':
        await this.studio.mergeItemsToPdf();
        break;
      case 'rotatePdf':
        await this.studio.rotatePdf(String(p.id), Number(p.angle) as 90 | 180 | 270);
        break;
      case 'splitPdf':
        await this.studio.splitPdf(String(p.id), String(p.range || '1'));
        break;
      case 'watermarkPdf':
        await this.studio.watermarkPdf(String(p.id), String(p.text || 'CONFIDENTIAL'));
        break;
      case 'convertImage':
        await this.studio.convertImageFormat(String(p.id), (p.format as 'png' | 'jpg') || 'png');
        break;
      case 'zipTray':
        await this.studio.zipAllItems();
        break;
      case 'askMakiAboutItem': {
        const item = this.studio.getSnapshot().droppedItems.find((i) => i.id === String(p.id));
        if (item) {
          if (item.kind === 'image') {
            this.gemini.attachImageFromPath(item.path);
          }
          this.gemini.isNotchChatMode = true;
          this.selectedTab = 'Capy';
          this.setExpanded(true);
          if (item.kind === 'audio') {
            void this.gemini.sendMessage(`Maki, tolong bantu rangkum atau beri catatan untuk file rekaman suara "${item.name}" ini ya! 🎙️`, {
              onStartThinking: () => {
                this.currentAction = 'typingLaptop';
                if (this.isOnDesktop && !this.gemini.isDesktopChatOpen) {
                  this.showDesktopBubble('bentar ya kubantu rangkum.. 🎧', 4000);
                }
              },
              onReplySuccess: (preview) => {
                this.xp += 4;
                this.mood = Math.min(100, this.mood + 2);
                this.currentAction = 'happyPet';
                this.savePersisted();
                if (this.isOnDesktop && !this.gemini.isDesktopChatOpen) {
                  this.showDesktopBubble(preview, 4200);
                }
              },
              onReplyError: () => {
                this.currentAction = 'chill';
              },
            });
          }
        }
        break;
      }

      // Clipboard History
      case 'copyClipboardEntry': {
        const entry = this.clipboardHistory.find((c) => c.id === String(p.id));
        if (entry) {
          if (entry.kind === 'image' && entry.previewDataUrl) {
            clipboard.writeImage(nativeImage.createFromDataURL(entry.previewDataUrl));
          } else {
            this.lastClipText = entry.text;
            clipboard.writeText(entry.text);
          }
          this.showContextualTip('udah disalin ulang ya');
        }
        break;
      }
      case 'clearClipboardHistory':
        this.clipboardHistory = [];
        break;

      // Focus Timer
      case 'startTimer': {
        const secs = Math.max(10, Number(p.seconds) || 1500);
        this.timerTotal = secs;
        this.timerRemaining = secs;
        this.timerRunning = true;
        this.timerAlert = false;
        this.showContextualTip('semangat fokusnya ya!');
        break;
      }
      case 'toggleTimerPause':
        if (this.timerTotal > 0) {
          this.timerRunning = !this.timerRunning;
          this.timerAlert = false;
        }
        break;
      case 'resetTimer':
        this.timerTotal = 0;
        this.timerRemaining = 0;
        this.timerRunning = false;
        this.timerAlert = false;
        break;

      // Gemini AI Chat ("Tanya Maki")
      case 'scanCache':
        void this.cleaner.startScan();
        break;
      case 'cleanCache':
        void this.cleanCacheInteractive();
        break;
      case 'openNotchChat':
        this.gemini.isNotchChatMode = true;
        this.selectedTab = 'Capy';
        this.setExpanded(true);
        break;
      case 'closeNotchChat':
        this.gemini.isNotchChatMode = false;
        break;
      case 'toggleDesktopChat':
        this.gemini.isDesktopChatOpen = !this.gemini.isDesktopChatOpen;
        this.syncDesktopWindowSizeForChat();
        break;
      case 'toggleGeminiSettings':
        this.gemini.isShowingSettings = !this.gemini.isShowingSettings;
        break;
      case 'setGeminiModel':
        this.gemini.setSelectedModel(p.model as MakiGeminiModel);
        break;
      case 'saveGeminiApiKey':
        this.gemini.updateAPIKey(String(p.apiKey || ''), p.provider ? (String(p.provider) as any) : undefined);
        this.gemini.isShowingSettings = false;
        break;
      case 'clearGeminiApiKey':
        this.gemini.clearAPIKey(p.provider ? (String(p.provider) as any) : undefined);
        break;
      case 'newGeminiConversation':
        this.gemini.startNewConversation();
        this.showContextualTip('siap, ngobrol topik baru yuk');
        break;
      case 'attachScreenshotToGemini':
        if (!this.gemini.attachLatestScreenshotOrClipboard()) {
          this.isModalOpen = true;
          try {
            await this.gemini.pickImageDialog(
              this.gemini.isDesktopChatOpen ? this.desktopWin : this.islandWin
            );
          } finally {
            this.isModalOpen = false;
          }
        }
        break;
      case 'clearGeminiAttachment':
        this.gemini.pendingAttachment = null;
        break;
      case 'cancelGeminiThinking':
        this.gemini.cancelCurrentTask();
        this.currentAction = 'chill';
        if (this.isOnDesktop && !this.gemini.isDesktopChatOpen) {
          this.showDesktopBubble('dibatalkan yaa', 2000);
        }
        this.scheduleBroadcast();
        break;
      case 'sendGeminiMessage':
        void this.gemini.sendMessage(String(p.text || ''), {
          onStartThinking: (hasAtt) => {
            this.currentAction = hasAtt ? 'readingBook' : 'typingLaptop';
            if (this.isOnDesktop && !this.gemini.isDesktopChatOpen) {
              this.showDesktopBubble(hasAtt ? 'bentar kulihat gambarnya..' : 'bentar mikir dulu..', 4000);
            }
          },
          onReplySuccess: (preview) => {
            this.xp += 4;
            this.mood = Math.min(100, this.mood + 2);
            this.currentAction = 'happyPet';
            this.registerSquish();
            this.savePersisted();
            if (this.isOnDesktop && !this.gemini.isDesktopChatOpen) {
              this.showDesktopBubble(preview, 4200);
            }
            this.scheduleActionReset(1800);
          },
          onReplyError: () => {
            if (this.currentAction === 'typingLaptop' || this.currentAction === 'readingBook') {
              this.currentAction = 'chill';
            }
          },
        });
        break;

      // Onboarding & Update Actions
      case 'openOnboarding':
        this.isShowingOnboarding = true;
        this.setExpanded(true);
        break;
      case 'closeOnboarding':
        this.isShowingOnboarding = false;
        this.hasCompletedOnboarding = true;
        this.savePersisted();
        break;
      case 'openExternalUrl':
        if (p.url) void shell.openExternal(String(p.url));
        break;
      case 'checkUpdate':
        void this.checkForGitHubUpdates(true);
        break;
      case 'applyUpdate':
        if (this.updateAvailable?.downloadUrl) {
          void this.downloadAndApplyWindowsUpdate(this.updateAvailable.downloadUrl);
        } else {
          void this.checkForGitHubUpdates(true);
        }
        break;
    }
    this.scheduleBroadcast();
  }

  private showNotesToast(msg: string) {
    if (this.toastTimeout) clearTimeout(this.toastTimeout);
    this.notesToast = msg;
    this.toastTimeout = setTimeout(() => {
      this.notesToast = null;
      this.scheduleBroadcast();
    }, 2200);
  }

  private formatSeconds(sec: number): string {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  public buildStateSnapshot(): SharedAppState {
    const studioSnap = this.studio.getSnapshot();
    const level = Math.max(1, Math.floor(this.xp / 50) + 1);
    const levelProgress = (this.xp % 50) / 50;

    return {
      isIslandVisible: this.isIslandVisible,
      isExpanded: this.isExpanded,
      selectedTab: this.selectedTab,
      isPinned: this.isPinned,
      isLaunchAtLogin: this.isLaunchAtLogin,
      isMicMuted: this.isMicMuted,
      isMirrorOpen: this.isMirrorOpen,

      mood: this.mood,
      fullness: this.fullness,
      xp: this.xp,
      level,
      levelProgress,
      orangesOnHead: this.orangesOnHead,
      isOnsenMode: this.isOnsenMode,
      mascotModel: this.mascotModel,
      showInCompactNotch: this.showInCompactNotch,
      isOnDesktop: this.isOnDesktop,
      desktopRoamEnabled: this.desktopRoamEnabled,
      isDraggingOnDesktop: this.isDraggingOnDesktop,
      isChasingCursor: this.isChasingCursor,
      isMouthOpenForDrop: this.isMouthOpenForDrop,
      desktopPointerInside: this.desktopPointerInside,
      isReturningToNotch: this.isReturningToNotch,
      notchClimbProgress: this.notchClimbProgress,
      currentAction: this.currentAction,
      eatingEmoji: this.eatingEmoji,
      lookVector: this.lookVector,
      lastSquishTime: this.lastSquishTime,
      speechBubble: this.speechBubble,
      contextualTip: this.contextualTip,
      desktopBubble: this.desktopBubble,
      heartBurstSeq: this.heartBurstSeq,
      posX: this.posX,
      facingRight: this.facingRight,

      // Companion Moko state
      hasCompanion: !!(this.companionWin && !this.companionWin.isDestroyed()),
      companionBubble: this.companionBubble,
      companionAction: this.companionAction as import('../shared/types').CapyActionType,
      companionFacingRight: this.companionFacingRight,
      companionOranges: this.companionOranges,
      companionIsOnsen: this.companionIsOnsen,

      messages: this.gemini.messages,
      isThinking: this.gemini.isThinking,
      pendingAttachment: this.gemini.pendingAttachment,
      selectedModel: this.gemini.selectedModel,
      selectedProvider: this.gemini.currentProvider,
      activeProviderName: this.gemini.currentProviderName,
      isNotchChatMode: this.gemini.isNotchChatMode,
      isDesktopChatOpen: this.gemini.isDesktopChatOpen,
      isShowingGeminiSettings: this.gemini.isShowingSettings,
      hasAPIKey: this.gemini.hasAPIKey,
      maskedAPIKey: this.gemini.maskedAPIKey,
      providerKeyStatuses: this.gemini.providerKeyStatuses,

      currentTrack: getCurrentTrackSnapshot(),
      calendarEvents: [
        ...this.localCalendarEvents,
        ...this.icsCalendarEvents,
        ...this.builtInHolidays(),
      ],
      googleICSUrl: this.googleICSUrl,
      isSyncingICS: this.isSyncingICS,
      calendarError: this.calendarError,
      isShowingCalendarSettings: this.isShowingCalendarSettings,

      scratchpadText: this.scratchpadText,
      todos: this.todos,
      notesToast: this.notesToast,

      launcherItems: this.launcherItems,

      droppedItems: studioSnap.droppedItems,
      activeStudioItemId: studioSnap.activeStudioItemId,
      trayBusy: studioSnap.trayBusy,
      trayBanner: studioSnap.trayBanner,

      system: getSystemMetricsSnapshot(),
      clipboardHistory: this.clipboardHistory,
      timer: {
        totalSeconds: this.timerTotal,
        remainingSeconds: this.timerRemaining,
        isRunning: this.timerRunning,
        isTimeUpAlert: this.timerAlert,
        formattedTime: this.formatSeconds(this.timerRemaining),
        progress: this.timerTotal > 0 ? this.timerRemaining / this.timerTotal : 0,
      },
      cacheCleaner: this.cleaner.state,
      isShowingOnboarding: this.isShowingOnboarding,
      updateAvailable: this.updateAvailable,
    };
  }

  private scheduleBroadcast() {
    if (this.broadcastScheduled) return;
    this.broadcastScheduled = true;
    setImmediate(() => {
      this.broadcastScheduled = false;
      const snap = this.buildStateSnapshot();
      if (this.islandWin && !this.islandWin.isDestroyed()) {
        this.islandWin.webContents.send('maki:state', snap);
      }
      if (this.desktopWin && !this.desktopWin.isDestroyed()) {
        this.desktopWin.webContents.send('maki:state', snap);
      }
      if (this.companionWin && !this.companionWin.isDestroyed()) {
        this.companionWin.webContents.send('maki:state', snap);
      }
    });
  }
}

app.whenReady().then(() => {
  const controller = new MakiMainController();
  void controller.init();
});

app.on('window-all-closed', () => {
  // Keep alive in Windows System Tray unless explicitly quit
});
