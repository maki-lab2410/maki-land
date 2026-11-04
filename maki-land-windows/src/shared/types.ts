export type IslandTab =
  | 'maki-land'
  | 'Capy'
  | 'Notes'
  | 'Launch'
  | 'Tray'
  | 'System'
  | 'Clipboard'
  | 'Timer';

export const ALL_ISLAND_TABS: { id: IslandTab; label: string; icon: string }[] = [
  { id: 'maki-land', label: 'maki-land', icon: '✨' },
  { id: 'Capy', label: 'Capy', icon: '🐾' },
  { id: 'Notes', label: 'Notes', icon: '📝' },
  { id: 'Launch', label: 'Launch', icon: '📱' },
  { id: 'Tray', label: 'Tray', icon: '📥' },
  { id: 'System', label: 'System', icon: '📊' },
  { id: 'Clipboard', label: 'Clipboard', icon: '📋' },
  { id: 'Timer', label: 'Timer', icon: '⏱️' },
];

export type IslandCategory = 'home' | 'files' | 'notes' | 'system';

export interface IslandCategoryGroup {
  id: IslandCategory;
  label: string;
  icon: string;
  tabs: { id: IslandTab; label: string; icon: string }[];
}

export const ISLAND_CATEGORY_GROUPS: IslandCategoryGroup[] = [
  {
    id: 'home',
    label: 'Beranda',
    icon: '🏠',
    tabs: [
      { id: 'maki-land', label: 'Musik & Jadwal', icon: '✨' },
      { id: 'Capy', label: 'Capy & AI', icon: '🐾' },
    ],
  },
  {
    id: 'files',
    label: 'Berkas',
    icon: '📁',
    tabs: [
      { id: 'Tray', label: 'Tray & Studio', icon: '📥' },
    ],
  },
  {
    id: 'notes',
    label: 'Catatan',
    icon: '📝',
    tabs: [
      { id: 'Notes', label: 'Notes & To-Do', icon: '📝' },
      { id: 'Timer', label: 'Timer Fokus', icon: '⏳' },
      { id: 'Clipboard', label: 'Papan Klip', icon: '📋' },
    ],
  },
  {
    id: 'system',
    label: 'Sistem',
    icon: '⚙️',
    tabs: [
      { id: 'System', label: 'Monitor Sistem', icon: '📊' },
      { id: 'Launch', label: 'Peluncur Cepat', icon: '🚀' },
    ],
  },
];

export function getCategoryForTab(tab: IslandTab): IslandCategory {
  for (const group of ISLAND_CATEGORY_GROUPS) {
    if (group.tabs.some((t) => t.id === tab)) {
      return group.id;
    }
  }
  return 'home';
}

export type CapyMascotModel = 'classic' | 'plushie';

export type CapyFood = 'Jeruk' | 'Semangka' | 'Sayur';

export const CAPY_FOODS: { id: CapyFood; emoji: string }[] = [
  { id: 'Jeruk', emoji: '🍊' },
  { id: 'Semangka', emoji: '🍉' },
  { id: 'Sayur', emoji: '🥬' },
];

export type CapyRole =
  | 'djMusic'
  | 'habitat'
  | 'scholarNotes'
  | 'pilotLauncher'
  | 'builderTray'
  | 'mechanicSystem'
  | 'detectiveClipboard'
  | 'senseiTimer';

export function roleFromTab(tab: IslandTab): CapyRole {
  switch (tab) {
    case 'maki-land':
      return 'djMusic';
    case 'Capy':
      return 'habitat';
    case 'Notes':
      return 'scholarNotes';
    case 'Launch':
      return 'pilotLauncher';
    case 'Tray':
      return 'builderTray';
    case 'System':
      return 'mechanicSystem';
    case 'Clipboard':
      return 'detectiveClipboard';
    case 'Timer':
      return 'senseiTimer';
  }
}

export function roleBadgeLabel(role: CapyRole): string {
  switch (role) {
    case 'djMusic':
      return '🎧 DJ Maki';
    case 'habitat':
      return '🐾 Maki';
    case 'scholarNotes':
      return '👓 Sekretaris';
    case 'pilotLauncher':
      return '🚀 Kapten';
    case 'builderTray':
      return '👷 Studio';
    case 'mechanicSystem':
      return '🔧 Mekanik';
    case 'detectiveClipboard':
      return '🔍 Detektif';
    case 'senseiTimer':
      return '🔥 Sensei';
  }
}

export type CapyActionType =
  | 'chill'
  | 'walking'
  | 'happyPet'
  | 'ticklish'
  | 'dizzy'
  | 'brushed'
  | 'eating'
  | 'swallowing'
  | 'sleeping'
  | 'sippingTea'
  | 'butterflyChase'
  | 'jugglingOranges'
  | 'blowingBubbles'
  | 'typingLaptop'
  | 'readingBook'
  | 'stretching';

export function isIdleShowActivity(action: CapyActionType): boolean {
  return (
    action === 'sippingTea' ||
    action === 'butterflyChase' ||
    action === 'jugglingOranges' ||
    action === 'blowingBubbles' ||
    action === 'typingLaptop' ||
    action === 'readingBook' ||
    action === 'stretching'
  );
}

export type MakiAIProvider =
  | 'gemini'
  | 'groq'
  | 'openai'
  | 'deepseek'
  | 'openrouter'
  | 'anthropic'
  | 'ollama';

export interface AIProviderMeta {
  id: MakiAIProvider;
  name: string;
  icon: string;
  badge: string;
  placeholder: string;
  envVar: string;
  helpUrl: string;
  tip: string;
}

export const AI_PROVIDERS: AIProviderMeta[] = [
  {
    id: 'gemini',
    name: 'Google Gemini',
    icon: '🌿',
    badge: 'Official',
    placeholder: 'Tempel AIza... Gemini API Key di sini',
    envVar: 'GEMINI_API_KEY',
    helpUrl: 'https://aistudio.google.com/apikey',
    tip: 'Free tier murah & cepat via Google AI Studio.',
  },
  {
    id: 'groq',
    name: 'Groq (Super Fast)',
    icon: '⚡',
    badge: 'Gratis & Kilat',
    placeholder: 'Tempel gsk_... Groq API Key di sini',
    envVar: 'GROQ_API_KEY',
    helpUrl: 'https://console.groq.com/keys',
    tip: 'Gratis dengan kecepatan inferensi tertinggi di dunia (Llama 3.3)!',
  },
  {
    id: 'openai',
    name: 'OpenAI',
    icon: '🧠',
    badge: 'Populer',
    placeholder: 'Tempel sk-... OpenAI API Key di sini',
    envVar: 'OPENAI_API_KEY',
    helpUrl: 'https://platform.openai.com/api-keys',
    tip: 'GPT-4o Mini sangat hemat dan akurat.',
  },
  {
    id: 'deepseek',
    name: 'DeepSeek',
    icon: '🐋',
    badge: 'Reasoning Hemat',
    placeholder: 'Tempel sk-... DeepSeek API Key di sini',
    envVar: 'DEEPSEEK_API_KEY',
    helpUrl: 'https://platform.deepseek.com/api_keys',
    tip: 'DeepSeek-V3 & R1 penalaran mendalam dengan biaya sangat murah.',
  },
  {
    id: 'openrouter',
    name: 'OpenRouter',
    icon: '🌐',
    badge: 'All-in-One',
    placeholder: 'Tempel sk-or-... OpenRouter API Key di sini',
    envVar: 'OPENROUTER_API_KEY',
    helpUrl: 'https://openrouter.ai/keys',
    tip: 'Satu API Key untuk ratusan model AI sekaligus.',
  },
  {
    id: 'anthropic',
    name: 'Anthropic Claude',
    icon: '🎭',
    badge: 'Cerdas',
    placeholder: 'Tempel sk-ant-... Anthropic API Key di sini',
    envVar: 'ANTHROPIC_API_KEY',
    helpUrl: 'https://console.anthropic.com/settings/keys',
    tip: 'Claude 3.5 Sonnet & Haiku sangat ahli coding dan penalaran.',
  },
  {
    id: 'ollama',
    name: 'Ollama (Lokal)',
    icon: '🦙',
    badge: 'Offline / Bebas Biaya',
    placeholder: 'URL server Ollama (default: http://localhost:11434)',
    envVar: 'OLLAMA_HOST',
    helpUrl: 'https://ollama.com',
    tip: '100% jalan lokal di komputermu tanpa perlu kirim data ke internet!',
  },
];

export type MakiGeminiModel = string;

export interface AIModelOption {
  id: string;
  provider: MakiAIProvider;
  providerName: string;
  shortLabel: string;
  subtitle: string;
}

export const ALL_AI_MODELS: AIModelOption[] = [
  // Google Gemini
  { id: 'gemini-3.5-flash-lite', provider: 'gemini', providerName: 'Google Gemini', shortLabel: 'Gemini 3.5 Lite', subtitle: 'Super Cepat & Ringan' },
  { id: 'gemini-3.8-flash', provider: 'gemini', providerName: 'Google Gemini', shortLabel: 'Gemini 3.8 Flash', subtitle: 'Cerdas & Multimodal' },
  { id: 'gemini-2.5-flash', provider: 'gemini', providerName: 'Google Gemini', shortLabel: 'Gemini 2.5 Flash', subtitle: 'Hemat & Multimodal' },

  // Groq (Free & Instant)
  { id: 'groq:llama-3.3-70b-versatile', provider: 'groq', providerName: 'Groq', shortLabel: 'Llama 3.3 70B (Groq)', subtitle: 'Free Tier & Super Kencang ⚡' },
  { id: 'groq:llama-3.1-8b-instant', provider: 'groq', providerName: 'Groq', shortLabel: 'Llama 3.1 8B (Groq)', subtitle: 'Respon Kilat' },

  // OpenAI
  { id: 'openai:gpt-4o-mini', provider: 'openai', providerName: 'OpenAI', shortLabel: 'GPT-4o Mini', subtitle: 'Cerdas & Hemat Token' },
  { id: 'openai:gpt-4o', provider: 'openai', providerName: 'OpenAI', shortLabel: 'GPT-4o', subtitle: 'Flagship Multimodal' },

  // DeepSeek
  { id: 'deepseek:deepseek-chat', provider: 'deepseek', providerName: 'DeepSeek', shortLabel: 'DeepSeek V3', subtitle: 'Pintar & Terjangkau' },
  { id: 'deepseek:deepseek-reasoner', provider: 'deepseek', providerName: 'DeepSeek', shortLabel: 'DeepSeek R1', subtitle: 'Penalaran Berpikir Mendalam' },

  // OpenRouter
  { id: 'openrouter:meta-llama/llama-3.3-70b-instruct', provider: 'openrouter', providerName: 'OpenRouter', shortLabel: 'Llama 3.3 (OpenRouter)', subtitle: 'Hub Multi-Model Universal' },
  { id: 'openrouter:deepseek/deepseek-r1', provider: 'openrouter', providerName: 'OpenRouter', shortLabel: 'DeepSeek R1 (OpenRouter)', subtitle: 'Reasoning via OpenRouter' },

  // Anthropic
  { id: 'anthropic:claude-3-5-haiku-20241022', provider: 'anthropic', providerName: 'Anthropic', shortLabel: 'Claude 3.5 Haiku', subtitle: 'Gesit & Alami' },
  { id: 'anthropic:claude-3-5-sonnet-20241022', provider: 'anthropic', providerName: 'Anthropic', shortLabel: 'Claude 3.5 Sonnet', subtitle: 'Coding & Analisis Terbaik' },

  // Ollama (Offline / Local)
  { id: 'ollama:llama3.2', provider: 'ollama', providerName: 'Ollama (Lokal)', shortLabel: 'Llama 3.2 (Lokal)', subtitle: 'Offline di PC via Ollama' },
  { id: 'ollama:qwen2.5', provider: 'ollama', providerName: 'Ollama (Lokal)', shortLabel: 'Qwen 2.5 (Lokal)', subtitle: 'Offline di PC via Ollama' },
];

export const GEMINI_MODELS = ALL_AI_MODELS;

export interface MakiChatAttachment {
  id: string;
  name: string;
  mimeType: string;
  base64Data: string;
  dataUrl: string;
  sourcePath?: string;
}

export interface MakiChatMessage {
  id: string;
  sender: 'user' | 'maki' | 'error';
  text: string;
  timestamp: string;
  attachedImageName?: string;
  attachedImageDataUrl?: string;
  modelUsed?: string;
}

export type DroppedItemKind = 'pdf' | 'image' | 'audio' | 'other';

export interface DroppedItem {
  id: string;
  name: string;
  path: string;
  sizeBytes: number;
  sizeFormatted: string;
  kind: DroppedItemKind;
  badgeText: string;
  thumbnailDataUrl?: string;
  audioDataUrl?: string;
  pageCount?: number;
}

export interface TodoItem {
  id: string;
  title: string;
  isDone: boolean;
}

export interface LauncherItem {
  id: string;
  name: string;
  urlOrPath: string;
  iconEmoji: string;
  iconDataUrl?: string;
  isWeb: boolean;
}

export interface ClipboardEntry {
  id: string;
  kind: 'text' | 'image';
  text: string;
  previewDataUrl?: string;
  savedFilePath?: string;
  timestamp: string;
}

export interface CalendarEventItem {
  id: string;
  title: string;
  dateISO: string; // YYYY-MM-DD
  timeLabel: string;
  isAllDay: boolean;
  source: 'Local' | 'Google' | 'Holiday';
  colorHex: string;
}

export interface TrackInfo {
  title: string;
  artist: string;
  appName: string;
  isPlaying: boolean;
}

export interface SystemMetrics {
  cpuPercent: number;
  ramUsedGB: number;
  ramTotalGB: number;
  ramPercent: number;
  batteryLevel: number;
  isCharging: boolean;
  hasBattery: boolean;
}

export interface TimerSnapshot {
  totalSeconds: number;
  remainingSeconds: number;
  isRunning: boolean;
  isTimeUpAlert: boolean;
  formattedTime: string;
  progress: number;
}

export interface SharedAppState {
  // Island UI
  isIslandVisible: boolean;
  isExpanded: boolean;
  isShowingOnboarding: boolean;
  updateAvailable: {
    version: string;
    url: string;
    notes: string;
    downloadUrl?: string;
    isDownloading?: boolean;
    downloadPercent?: number;
  } | null;
  selectedTab: IslandTab;
  isPinned: boolean;
  isLaunchAtLogin: boolean;
  isMicMuted: boolean;
  isMirrorOpen: boolean;

  // Capybara companion
  mood: number;
  fullness: number;
  xp: number;
  level: number;
  levelProgress: number;
  orangesOnHead: number;
  isOnsenMode: boolean;
  mascotModel: CapyMascotModel;
  showInCompactNotch: boolean;
  isOnDesktop: boolean;
  desktopRoamEnabled: boolean;
  isDraggingOnDesktop: boolean;
  isChasingCursor: boolean;
  isMouthOpenForDrop: boolean;
  desktopPointerInside: boolean;
  isReturningToNotch: boolean;
  notchClimbProgress: number;
  currentAction: CapyActionType;
  eatingEmoji: string;
  lookVector: { x: number; y: number };
  lastSquishTime: number;
  speechBubble: string | null;
  contextualTip: string | null;
  desktopBubble: string | null;
  heartBurstSeq: number;
  posX: number;
  facingRight: boolean;

  // Multi-Monitor Companion (Moko)
  hasCompanion: boolean;
  companionBubble: string | null;
  companionAction: CapyActionType;
  companionFacingRight: boolean;
  companionOranges: number;
  companionIsOnsen: boolean;

  // Multi-Provider AI (Gemini, Groq, OpenAI, DeepSeek, OpenRouter, Anthropic, Ollama)
  messages: MakiChatMessage[];
  isThinking: boolean;
  pendingAttachment: MakiChatAttachment | null;
  selectedModel: MakiGeminiModel;
  selectedProvider: MakiAIProvider;
  activeProviderName: string;
  isNotchChatMode: boolean;
  isDesktopChatOpen: boolean;
  isShowingGeminiSettings: boolean;
  hasAPIKey: boolean;
  maskedAPIKey: string;
  providerKeyStatuses: Record<string, boolean>;

  // Media & Calendar
  currentTrack: TrackInfo;
  calendarEvents: CalendarEventItem[];
  googleICSUrl: string;
  isSyncingICS: boolean;
  calendarError: string | null;
  isShowingCalendarSettings: boolean;

  // Notes & To-Do
  scratchpadText: string;
  todos: TodoItem[];
  notesToast: string | null;

  // Launcher
  launcherItems: LauncherItem[];

  // Tray & Studio
  droppedItems: DroppedItem[];
  activeStudioItemId: string | null;
  trayBusy: boolean;
  trayBanner: { message: string; isError: boolean } | null;

  // System, Clipboard, Timer, Cache Cleaner
  system: SystemMetrics;
  clipboardHistory: ClipboardEntry[];
  timer: TimerSnapshot;
  cacheCleaner: CacheCleanerState;
}

export interface CacheCleanerState {
  isScanning: boolean;
  isCleaning: boolean;
  totalSafeBytes: number;
  formattedSafeSize: string;
  lastFreedBytes: number;
  formattedFreedSize: string;
  progressText: string;
  hasCompletedInitialScan: boolean;
}

export const ISLAND_CANVAS_WIDTH = 740;
export const ISLAND_CANVAS_HEIGHT = 480;
export const DESKTOP_NORMAL_WIDTH = 264;
export const DESKTOP_NORMAL_HEIGHT = 194;
export const DESKTOP_CHAT_WIDTH = 336;
export const DESKTOP_CHAT_HEIGHT = 376;

export function computeTargetIslandSize(
  state: SharedAppState,
  overrideTab?: IslandTab,
  isVoiceRecorderOpen?: boolean
): { width: number; height: number } {
  if (state.isShowingOnboarding) {
    return { width: 680, height: 260 };
  }
  if (!state.isExpanded) {
    const showMini = state.showInCompactNotch && !state.isOnDesktop;
    return { width: showMini ? 238 : 210, height: 32 };
  }
  if (state.isMirrorOpen) {
    return { width: 660, height: 420 };
  }
  if (isVoiceRecorderOpen) {
    return { width: 660, height: 210 };
  }
  const tab = overrideTab || state.selectedTab;
  switch (tab) {
    case 'Tray': {
      const studio = state.droppedItems.find((i) => i.id === state.activeStudioItemId);
      if (studio) {
        if (studio.kind === 'pdf') return { width: 680, height: 294 };
        if (studio.kind === 'image') return { width: 660, height: 242 };
        return { width: 660, height: 198 };
      }
      return { width: 660, height: 162 };
    }
    case 'maki-land':
      return state.isShowingCalendarSettings
        ? { width: 660, height: 184 }
        : { width: 660, height: 160 };
    case 'Notes':
      return { width: 680, height: 202 };
    case 'Capy':
      return state.isNotchChatMode ? { width: 668, height: 262 } : { width: 660, height: 188 };
    case 'Launch':
      return { width: 660, height: 166 };
    case 'Clipboard':
      return { width: 660, height: 184 };
    case 'System':
      return { width: 660, height: 198 };
    case 'Timer':
      return { width: 660, height: 158 };
    default:
      return { width: 660, height: 160 };
  }
}
