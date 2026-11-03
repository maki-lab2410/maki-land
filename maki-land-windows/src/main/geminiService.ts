import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { app, clipboard, dialog, nativeImage, BrowserWindow } from 'electron';
import {
  AI_PROVIDERS,
  ALL_AI_MODELS,
  MakiAIProvider,
  MakiChatAttachment,
  MakiChatMessage,
  MakiGeminiModel,
  SharedAppState,
} from '../shared/types';
import { StudioService } from './studioService';

interface LocalAIConfig {
  apiKey?: string; // legacy / gemini fallback
  providerKeys?: Record<string, string>;
  selectedModel: MakiGeminiModel;
}

interface InteractionResponsePayload {
  id?: string;
  status?: string;
  model?: string;
  steps?: {
    type?: string;
    content?: { type?: string; text?: string }[];
  }[];
  error?: { message?: string; code?: string };
}

export function parseModelProvider(model: string): { provider: MakiAIProvider; actualModel: string } {
  if (model.startsWith('groq:')) return { provider: 'groq', actualModel: model.slice(5) };
  if (model.startsWith('openai:')) return { provider: 'openai', actualModel: model.slice(7) };
  if (model.startsWith('deepseek:')) return { provider: 'deepseek', actualModel: model.slice(9) };
  if (model.startsWith('openrouter:')) return { provider: 'openrouter', actualModel: model.slice(11) };
  if (model.startsWith('anthropic:')) return { provider: 'anthropic', actualModel: model.slice(10) };
  if (model.startsWith('ollama:')) return { provider: 'ollama', actualModel: model.slice(7) };
  return { provider: 'gemini', actualModel: model };
}

export class GeminiManager {
  public messages: MakiChatMessage[] = [];
  public isThinking = false;
  public pendingAttachment: MakiChatAttachment | null = null;
  public selectedModel: MakiGeminiModel = 'gemini-3.5-flash-lite';
  public isNotchChatMode = false;
  public isDesktopChatOpen = false;
  public isShowingSettings = false;

  private apiKey = ''; // legacy Gemini key
  private providerKeys: Record<string, string> = {};
  private lastInteractionId: string | null = null;
  private lastInteractionModel: string | null = null;
  private abortCtrl: AbortController | null = null;

  private onChange: () => void;
  private getWorkspaceState: () => SharedAppState;
  private studio: StudioService;

  constructor(
    studio: StudioService,
    getWorkspaceState: () => SharedAppState,
    onChange: () => void
  ) {
    this.studio = studio;
    this.getWorkspaceState = getWorkspaceState;
    this.onChange = onChange;
    this.loadConfig();
    this.loadHistory();
  }

  private get configPath(): string {
    return path.join(app.getPath('userData'), 'gemini_config.json');
  }

  private get historyPath(): string {
    return path.join(app.getPath('userData'), 'maki_chat_history.json');
  }

  public get currentProvider(): MakiAIProvider {
    return parseModelProvider(this.selectedModel).provider;
  }

  public get currentProviderName(): string {
    const meta = AI_PROVIDERS.find((p) => p.id === this.currentProvider);
    return meta ? meta.name : this.currentProvider;
  }

  public effectiveKeyFor(provider: MakiAIProvider): string {
    const direct = (this.providerKeys[provider] || '').trim();
    if (direct) return direct;

    if (provider === 'gemini') {
      const leg = this.apiKey.trim();
      if (leg) return leg;
      return (process.env.GEMINI_API_KEY || '').trim();
    }
    if (provider === 'groq') return (process.env.GROQ_API_KEY || '').trim();
    if (provider === 'openai') return (process.env.OPENAI_API_KEY || '').trim();
    if (provider === 'deepseek') return (process.env.DEEPSEEK_API_KEY || '').trim();
    if (provider === 'openrouter') return (process.env.OPENROUTER_API_KEY || '').trim();
    if (provider === 'anthropic') return (process.env.ANTHROPIC_API_KEY || '').trim();
    if (provider === 'ollama') {
      const host = (process.env.OLLAMA_HOST || '').trim();
      return host || 'http://localhost:11434';
    }
    return '';
  }

  public hasKeyFor(provider: MakiAIProvider): boolean {
    if (provider === 'ollama') return true; // Ollama is local, no required auth key
    return this.effectiveKeyFor(provider).length > 0;
  }

  public get effectiveAPIKey(): string {
    return this.effectiveKeyFor(this.currentProvider);
  }

  public get hasAPIKey(): boolean {
    return this.hasKeyFor(this.currentProvider);
  }

  public get maskedAPIKey(): string {
    return this.maskedKeyFor(this.currentProvider);
  }

  public maskedKeyFor(provider: MakiAIProvider): string {
    if (provider === 'ollama') {
      const url = this.effectiveKeyFor('ollama');
      return url || 'http://localhost:11434';
    }
    const k = this.effectiveKeyFor(provider);
    if (!k) return 'Belum diatur';
    if (k.length <= 10) return '•'.repeat(k.length);
    return `${k.slice(0, 6)}••••••••${k.slice(-4)}`;
  }

  public get providerKeyStatuses(): Record<string, boolean> {
    const res: Record<string, boolean> = {};
    for (const p of AI_PROVIDERS) {
      res[p.id] = this.hasKeyFor(p.id);
    }
    return res;
  }

  private loadConfig() {
    try {
      if (fs.existsSync(this.configPath)) {
        const raw = JSON.parse(fs.readFileSync(this.configPath, 'utf8')) as Partial<LocalAIConfig>;
        if (typeof raw.apiKey === 'string') this.apiKey = raw.apiKey.trim();
        if (raw.providerKeys && typeof raw.providerKeys === 'object') {
          this.providerKeys = { ...raw.providerKeys };
        }
        if (raw.selectedModel && typeof raw.selectedModel === 'string') {
          const match = ALL_AI_MODELS.find((m) => m.id === raw.selectedModel);
          if (match) this.selectedModel = raw.selectedModel;
        }
      }
    } catch {
      // ignore
    }
  }

  private saveConfig() {
    try {
      const payload: LocalAIConfig = {
        apiKey: this.apiKey,
        providerKeys: this.providerKeys,
        selectedModel: this.selectedModel,
      };
      fs.writeFileSync(this.configPath, JSON.stringify(payload, null, 2), { mode: 0o600 });
    } catch {
      // ignore
    }
  }

  private loadHistory() {
    try {
      if (fs.existsSync(this.historyPath)) {
        const saved = JSON.parse(fs.readFileSync(this.historyPath, 'utf8')) as MakiChatMessage[];
        if (Array.isArray(saved)) {
          this.messages = saved.slice(-24);
        }
      }
    } catch {
      // ignore
    }
  }

  private saveHistory() {
    try {
      fs.writeFileSync(this.historyPath, JSON.stringify(this.messages.slice(-24), null, 2));
    } catch {
      // ignore
    }
  }

  public updateAPIKey(newKey: string, provider?: MakiAIProvider) {
    const target = provider || this.currentProvider;
    const clean = newKey.trim();
    this.providerKeys[target] = clean;
    if (target === 'gemini') {
      this.apiKey = clean;
    }
    this.lastInteractionId = null;
    this.lastInteractionModel = null;
    this.saveConfig();
    this.onChange();
  }

  public clearAPIKey(provider?: MakiAIProvider) {
    const target = provider || this.currentProvider;
    delete this.providerKeys[target];
    if (target === 'gemini') {
      this.apiKey = '';
    }
    this.lastInteractionId = null;
    this.lastInteractionModel = null;
    this.saveConfig();
    this.onChange();
  }

  public setSelectedModel(model: MakiGeminiModel) {
    this.selectedModel = model;
    this.saveConfig();
    this.onChange();
  }

  public startNewConversation() {
    this.abortCtrl?.abort();
    this.abortCtrl = null;
    this.isThinking = false;
    this.messages = [];
    this.pendingAttachment = null;
    this.lastInteractionId = null;
    this.lastInteractionModel = null;
    this.saveHistory();
    this.onChange();
  }

  public cancelActiveRequest() {
    if (this.abortCtrl) {
      this.abortCtrl.abort();
      this.abortCtrl = null;
    }
    this.isThinking = false;
    this.onChange();
  }

  public cancelCurrentTask() {
    this.cancelActiveRequest();
  }

  public attachFromNativeImage(img: Electron.NativeImage, name: string, sourcePath?: string): boolean {
    if (img.isEmpty()) return false;
    const size = img.getSize();
    if (size.width < 4 || size.height < 4) return false;

    const maxDim = 1440;
    let processed = img;
    if (size.width > maxDim || size.height > maxDim) {
      if (size.width >= size.height) {
        processed = img.resize({ width: maxDim });
      } else {
        processed = img.resize({ height: maxDim });
      }
    }
    const jpegBuf = processed.toJPEG(84);
    const thumb = processed.resize({ width: 140 }).toDataURL();

    this.pendingAttachment = {
      id: crypto.randomUUID(),
      name,
      mimeType: 'image/jpeg',
      base64Data: jpegBuf.toString('base64'),
      dataUrl: thumb,
      sourcePath,
    };
    this.onChange();
    return true;
  }

  public attachImageFromPath(filePath: string): boolean {
    if (!filePath || !fs.existsSync(filePath)) return false;
    const img = nativeImage.createFromPath(filePath);
    if (img.isEmpty()) return false;
    return this.attachFromNativeImage(img, path.basename(filePath), filePath);
  }

  public attachLatestScreenshotOrClipboard(): boolean {
    const clipImg = clipboard.readImage();
    if (!clipImg.isEmpty() && clipImg.getSize().width > 4) {
      return this.attachFromNativeImage(clipImg, 'Clipboard Screenshot');
    }
    const trayImg = this.studio.getSnapshot().droppedItems.find((i) => i.kind === 'image');
    if (trayImg && this.attachImageFromPath(trayImg.path)) {
      return true;
    }
    const recent = this.studio.findLatestRecentScreenshotFile();
    if (recent && this.attachImageFromPath(recent)) {
      return true;
    }
    return false;
  }

  public async pickImageDialog(parent?: BrowserWindow | null): Promise<boolean> {
    const res = await dialog.showOpenDialog(parent || BrowserWindow.getAllWindows()[0], {
      title: 'Pilih Gambar untuk Ditanyakan ke Maki AI',
      filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'] }],
      properties: ['openFile'],
    });
    if (res.canceled || res.filePaths.length === 0) return false;
    return this.attachImageFromPath(res.filePaths[0]);
  }

  public async sendMessage(
    rawPrompt: string,
    hooks: {
      onStartThinking: (hasAttachment: boolean) => void;
      onReplySuccess: (shortPreview: string) => void;
      onReplyError: () => void;
    }
  ): Promise<void> {
    const trimmed = rawPrompt.trim();
    const attachment = this.pendingAttachment;
    if (!trimmed && !attachment) return;
    if (this.isThinking) return;

    const provider = this.currentProvider;
    if (!this.hasKeyFor(provider)) {
      this.isShowingSettings = true;
      const provMeta = AI_PROVIDERS.find((p) => p.id === provider);
      const name = provMeta ? provMeta.name : provider;
      this.messages.push({
        id: crypto.randomUUID(),
        sender: 'error',
        text: `API Key untuk ${name} belum diatur nih! Klik ikon 🔑 di pojok kanan atas untuk memasukkan key ya~ 🐾`,
        timestamp: new Date().toISOString(),
      });
      this.onChange();
      return;
    }

    const userText = trimmed || 'Tolong jelaskan isi gambar ini secara ringkas dan jelas.';
    const priorHistory = [...this.messages];

    this.messages.push({
      id: crypto.randomUUID(),
      sender: 'user',
      text: userText,
      timestamp: new Date().toISOString(),
      attachedImageName: attachment?.name,
      attachedImageDataUrl: attachment?.dataUrl,
    });
    this.pendingAttachment = null;
    this.isThinking = true;
    this.saveHistory();
    hooks.onStartThinking(Boolean(attachment));
    this.onChange();

    const activeKey = this.effectiveAPIKey;
    const systemInstruction = this.buildSystemInstruction();
    const preferred = this.selectedModel;

    this.abortCtrl = new AbortController();
    const signal = this.abortCtrl.signal;

    const reply = await this.dispatchUnifiedRequest(
      provider,
      preferred,
      activeKey,
      systemInstruction,
      userText,
      attachment,
      priorHistory,
      signal
    );

    if (signal.aborted) return;
    this.isThinking = false;

    if (reply.ok) {
      if (reply.interactionId) this.lastInteractionId = reply.interactionId;
      this.lastInteractionModel = reply.modelUsed;
      this.messages.push({
        id: crypto.randomUUID(),
        sender: 'maki',
        text: reply.text,
        timestamp: new Date().toISOString(),
        modelUsed: reply.modelUsed,
      });
      this.saveHistory();
      hooks.onReplySuccess(GeminiManager.shortBubblePreview(reply.text));
    } else {
      this.messages.push({
        id: crypto.randomUUID(),
        sender: 'error',
        text: reply.error,
        timestamp: new Date().toISOString(),
      });
      this.saveHistory();
      hooks.onReplyError();
    }
    this.onChange();
  }

  private async dispatchUnifiedRequest(
    provider: MakiAIProvider,
    modelId: string,
    apiKey: string,
    systemInstruction: string,
    userText: string,
    attachment: MakiChatAttachment | null,
    priorHistory: MakiChatMessage[],
    signal: AbortSignal
  ): Promise<
    | { ok: true; text: string; interactionId?: string | null; modelUsed: string }
    | { ok: false; error: string }
  > {
    const { actualModel } = parseModelProvider(modelId);

    // 1. Anthropic Claude
    if (provider === 'anthropic') {
      return this.sendAnthropicRequest(
        apiKey,
        actualModel,
        systemInstruction,
        userText,
        attachment,
        priorHistory,
        signal
      );
    }

    // 2. OpenAI / Groq / DeepSeek / OpenRouter / Ollama
    if (
      provider === 'openai' ||
      provider === 'groq' ||
      provider === 'deepseek' ||
      provider === 'openrouter' ||
      provider === 'ollama'
    ) {
      return this.sendOpenAICompatibleRequest(
        provider,
        apiKey,
        actualModel,
        systemInstruction,
        userText,
        attachment,
        priorHistory,
        signal
      );
    }

    // 3. Google Gemini (Default)
    return this.performGeminiWithFallback(
      apiKey,
      actualModel,
      systemInstruction,
      userText,
      attachment,
      priorHistory,
      signal
    );
  }

  // ==========================================
  // Provider 1: OpenAI-Compatible Handler
  // (Groq, OpenAI, DeepSeek, OpenRouter, Ollama)
  // ==========================================
  private async sendOpenAICompatibleRequest(
    provider: MakiAIProvider,
    apiKey: string,
    modelName: string,
    systemInstruction: string,
    userText: string,
    attachment: MakiChatAttachment | null,
    priorHistory: MakiChatMessage[],
    signal: AbortSignal
  ): Promise<
    | { ok: true; text: string; modelUsed: string }
    | { ok: false; error: string }
  > {
    let endpoint = 'https://api.openai.com/v1/chat/completions';
    if (provider === 'groq') endpoint = 'https://api.groq.com/openai/v1/chat/completions';
    else if (provider === 'deepseek') endpoint = 'https://api.deepseek.com/chat/completions';
    else if (provider === 'openrouter') endpoint = 'https://openrouter.ai/api/v1/chat/completions';
    else if (provider === 'ollama') {
      const base = (apiKey || 'http://localhost:11434').replace(/\/+$/, '');
      endpoint = `${base}/v1/chat/completions`;
    }

    const messages: Array<{ role: string; content: unknown }> = [
      { role: 'system', content: systemInstruction },
    ];

    // Add recent conversational context
    const valid = priorHistory.filter((m) => m.sender === 'user' || m.sender === 'maki').slice(-8);
    for (const m of valid) {
      messages.push({
        role: m.sender === 'user' ? 'user' : 'assistant',
        content: m.text,
      });
    }

    // Current turn (multimodal support if image present)
    if (attachment) {
      messages.push({
        role: 'user',
        content: [
          {
            type: 'image_url',
            image_url: {
              url: `data:${attachment.mimeType};base64,${attachment.base64Data}`,
            },
          },
          { type: 'text', text: userText },
        ],
      });
    } else {
      messages.push({ role: 'user', content: userText });
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey || 'ollama'}`,
    };
    if (provider === 'openrouter') {
      headers['HTTP-Referer'] = 'https://makiland.app';
      headers['X-Title'] = 'Maki-Land';
    }

    const body = {
      model: modelName,
      messages,
      max_tokens: 3000,
    };

    const timeout = setTimeout(() => this.abortCtrl?.abort(), 35000);
    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal,
      });

      const raw = await res.text();
      let decoded: any = null;
      try {
        decoded = JSON.parse(raw);
      } catch {
        decoded = null;
      }

      if (!res.ok) {
        const msg = decoded?.error?.message || raw || `HTTP ${res.status}`;
        if (res.status === 401 || res.status === 403) {
          return {
            ok: false,
            error: `API Key ${provider.toUpperCase()} salah atau ditolak (${res.status}). Cek menu 🔑 ya!\nDetail: ${msg}`,
          };
        }
        return {
          ok: false,
          error: `Gagal memproses respons dari ${provider} (${res.status}): ${msg}`,
        };
      }

      const reply = decoded?.choices?.[0]?.message?.content;
      if (!reply || typeof reply !== 'string' || !reply.trim()) {
        return {
          ok: false,
          error: 'Maki tidak mendapatkan respons teks (respons kosong). Coba lagi ya!',
        };
      }

      return {
        ok: true,
        text: reply.trim(),
        modelUsed: `${provider}:${modelName}`,
      };
    } catch (e) {
      if (signal.aborted) return { ok: false, error: 'Permintaan dibatalkan.' };
      return {
        ok: false,
        error: `Koneksi gagal ke server ${provider}: ${(e as Error).message}`,
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  // ==========================================
  // Provider 2: Anthropic Claude Handler
  // ==========================================
  private async sendAnthropicRequest(
    apiKey: string,
    modelName: string,
    systemInstruction: string,
    userText: string,
    attachment: MakiChatAttachment | null,
    priorHistory: MakiChatMessage[],
    signal: AbortSignal
  ): Promise<
    | { ok: true; text: string; modelUsed: string }
    | { ok: false; error: string }
  > {
    const messages: Array<{ role: 'user' | 'assistant'; content: unknown }> = [];

    const valid = priorHistory.filter((m) => m.sender === 'user' || m.sender === 'maki').slice(-6);
    for (const m of valid) {
      messages.push({
        role: m.sender === 'user' ? 'user' : 'assistant',
        content: m.text,
      });
    }

    if (attachment) {
      messages.push({
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: attachment.mimeType,
              data: attachment.base64Data,
            },
          },
          { type: 'text', text: userText },
        ],
      });
    } else {
      messages.push({ role: 'user', content: userText });
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    };

    const body = {
      model: modelName,
      max_tokens: 3000,
      system: systemInstruction,
      messages,
    };

    const timeout = setTimeout(() => this.abortCtrl?.abort(), 35000);
    try {
      const res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
        signal,
      });

      const raw = await res.text();
      let decoded: any = null;
      try {
        decoded = JSON.parse(raw);
      } catch {
        decoded = null;
      }

      if (!res.ok) {
        const msg = decoded?.error?.message || raw || `HTTP ${res.status}`;
        if (res.status === 401 || res.status === 403) {
          return {
            ok: false,
            error: `API Key Anthropic ditolak (${res.status}). Cek kembali di menu 🔑 ya!\nDetail: ${msg}`,
          };
        }
        return {
          ok: false,
          error: `Gagal memproses respons dari Anthropic (${res.status}): ${msg}`,
        };
      }

      const textParts = (decoded?.content || [])
        .filter((c: any) => c.type === 'text')
        .map((c: any) => c.text);
      const text = textParts.join('').trim();
      if (!text) {
        return { ok: false, error: 'Respons dari Claude kosong. Coba lagi ya!' };
      }

      return {
        ok: true,
        text,
        modelUsed: `anthropic:${modelName}`,
      };
    } catch (e) {
      if (signal.aborted) return { ok: false, error: 'Permintaan dibatalkan.' };
      return {
        ok: false,
        error: `Koneksi ke Anthropic timeout / gagal: ${(e as Error).message}`,
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  // ==========================================
  // Provider 3: Google Gemini Handler
  // ==========================================
  private candidateGeminiModels(preferred: string): string[] {
    return Array.from(
      new Set([
        preferred,
        'gemini-3.5-flash-lite',
        'gemini-3.8-flash',
        'gemini-2.5-flash',
      ])
    );
  }

  private async performGeminiWithFallback(
    apiKey: string,
    preferred: string,
    systemInstruction: string,
    userText: string,
    attachment: MakiChatAttachment | null,
    priorHistory: MakiChatMessage[],
    signal: AbortSignal
  ): Promise<
    | { ok: true; text: string; interactionId: string | null; modelUsed: string }
    | { ok: false; error: string }
  > {
    const models = this.candidateGeminiModels(preferred);
    let lastError = 'Koneksi ke Gemini gagal. Coba lagi sebentar ya.';

    for (const modelName of models) {
      if (signal.aborted) return { ok: false, error: 'Permintaan dibatalkan.' };

      const canReuse = this.lastInteractionId !== null && this.lastInteractionModel === modelName;
      const prevId = canReuse ? this.lastInteractionId : null;
      const promptText = prevId
        ? userText
        : this.injectLocalHistoryIfNeeded(userText, priorHistory);

      const first = await this.sendSingleGeminiInteraction(
        apiKey,
        modelName,
        systemInstruction,
        promptText,
        attachment,
        prevId,
        signal
      );

      if (first.kind === 'success') {
        return {
          ok: true,
          text: first.text,
          interactionId: first.interactionId,
          modelUsed: first.modelUsed,
        };
      }

      if (first.kind === 'retryWithoutPreviousId') {
        const fallbackPrompt = this.injectLocalHistoryIfNeeded(userText, priorHistory);
        const second = await this.sendSingleGeminiInteraction(
          apiKey,
          modelName,
          systemInstruction,
          fallbackPrompt,
          attachment,
          null,
          signal
        );
        if (second.kind === 'success') {
          return {
            ok: true,
            text: second.text,
            interactionId: second.interactionId,
            modelUsed: second.modelUsed,
          };
        }
        if (second.kind === 'fatal') return { ok: false, error: second.message };
        if (second.kind === 'overload') {
          lastError = second.message;
          continue;
        }
      } else if (first.kind === 'overload') {
        lastError = first.message;
        continue;
      } else if (first.kind === 'fatal') {
        return { ok: false, error: first.message };
      }
    }

    return { ok: false, error: lastError };
  }

  private async sendSingleGeminiInteraction(
    apiKey: string,
    model: string,
    systemInstruction: string,
    promptText: string,
    attachment: MakiChatAttachment | null,
    previousInteractionId: string | null,
    signal: AbortSignal
  ): Promise<
    | { kind: 'success'; text: string; interactionId: string | null; modelUsed: string }
    | { kind: 'retryWithoutPreviousId' }
    | { kind: 'overload'; message: string }
    | { kind: 'fatal'; message: string }
  > {
    const inputParts: Record<string, string>[] = [];
    if (attachment) {
      inputParts.push({
        type: 'image',
        data: attachment.base64Data,
        mime_type: attachment.mimeType,
      });
    }
    inputParts.push({
      type: 'text',
      text: promptText,
    });

    const thinkingLevel = model.includes('flash-lite') ? 'minimal' : 'low';
    const body: Record<string, unknown> = {
      model,
      system_instruction: systemInstruction,
      generation_config: {
        thinking_level: thinkingLevel,
        max_output_tokens: 4096,
      },
      input: inputParts,
    };
    if (previousInteractionId) {
      body.previous_interaction_id = previousInteractionId;
    }

    const timeout = setTimeout(() => this.abortCtrl?.abort(), 26000);
    try {
      const res = await fetch('https://generativelanguage.googleapis.com/v1beta/interactions', {
        method: 'POST',
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
          'Api-Revision': '2026-05-20',
        },
        body: JSON.stringify(body),
        signal,
      });

      const rawText = await res.text();
      let decoded: InteractionResponsePayload | null = null;
      try {
        decoded = JSON.parse(rawText) as InteractionResponsePayload;
      } catch {
        decoded = null;
      }

      if (res.ok) {
        const text = GeminiManager.extractModelOutputText(decoded);
        if (!text) {
          return {
            kind: 'fatal',
            message: 'Maki bingung mau jawab apa barusan (respons kosong). Coba tanya ulang ya!',
          };
        }
        return {
          kind: 'success',
          text,
          interactionId: decoded?.id || null,
          modelUsed: decoded?.model || model,
        };
      }

      const serverMsg = decoded?.error?.message || rawText || `HTTP ${res.status}`;
      if ((res.status === 400 || res.status === 404) && previousInteractionId) {
        return { kind: 'retryWithoutPreviousId' };
      }
      if (res.status === 503 || res.status === 429 || res.status === 500 || res.status === 404) {
        return {
          kind: 'overload',
          message: `Server / model ${model} sedang padat (${res.status}). Mencoba model alternatif...`,
        };
      }
      if (res.status === 401 || res.status === 403) {
        return {
          kind: 'fatal',
          message: `API Key Gemini ditolak (${res.status}). Cek kembali key di menu 🔑 ya! Detail: ${serverMsg}`,
        };
      }
      return {
        kind: 'fatal',
        message: `Gagal memproses jawaban (${res.status}): ${serverMsg}`,
      };
    } catch (e) {
      if (signal.aborted) {
        return { kind: 'fatal', message: 'Permintaan dibatalkan.' };
      }
      return {
        kind: 'overload',
        message: `Koneksi timeout ke ${model}: ${(e as Error).message}`,
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  private static extractModelOutputText(payload: InteractionResponsePayload | null): string {
    if (!payload?.steps) return '';
    const chunks: string[] = [];
    for (const step of payload.steps) {
      if (step.type === 'model_output' && Array.isArray(step.content)) {
        for (const part of step.content) {
          if (part.type === 'text' && part.text) {
            chunks.push(part.text);
          }
        }
      }
    }
    return chunks.join('').trim();
  }

  private injectLocalHistoryIfNeeded(userText: string, history: MakiChatMessage[]): string {
    const valid = history.filter((m) => m.sender === 'user' || m.sender === 'maki').slice(-6);
    if (valid.length === 0) return userText;
    const lines = ['[Konteks percakapan sebelumnya antara Pengguna dan Maki:]'];
    for (const t of valid) {
      const role = t.sender === 'user' ? 'Pengguna' : 'Maki';
      lines.push(`${role}: ${t.text.slice(0, 500)}`);
    }
    lines.push(`\n[Pesan terbaru Pengguna:]\n${userText}`);
    return lines.join('\n');
  }

  private buildSystemInstruction(): string {
    const s = this.getWorkspaceState();
    const nowStr = new Date().toLocaleString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    const ctxLines: string[] = [];
    ctxLines.push(`- Waktu lokal: ${nowStr}`);
    ctxLines.push(
      `- Status Maki: Level ${s.level}, Mood ${s.mood}%, Kenyang ${s.fullness}%, Jeruk di kepala: ${s.orangesOnHead}, Model: ${s.mascotModel}, Posisi: ${
        s.isOnDesktop ? 'sedang main di Desktop Windows' : 'sedang nongkrong di dalam Notch'
      }`
    );

    if (s.currentTrack.isPlaying && s.currentTrack.title) {
      ctxLines.push(
        `- Musik sedang diputar: "${s.currentTrack.title}" oleh ${
          s.currentTrack.artist || 'Unknown'
        } (${s.currentTrack.appName || 'Media Player'})`
      );
    }

    const todayISO = new Date().toISOString().slice(0, 10);
    const todayEvents = s.calendarEvents.filter((e) => e.dateISO === todayISO);
    if (todayEvents.length > 0) {
      const evStr = todayEvents
        .slice(0, 5)
        .map((e) => `${e.timeLabel} ${e.title}`)
        .join('; ');
      ctxLines.push(`- Jadwal Kalender hari ini: ${evStr}`);
    } else {
      ctxLines.push('- Jadwal Kalender hari ini: Kosong / tidak ada jadwal');
    }

    const pendingTodos = s.todos.filter((t) => !t.isDone);
    if (pendingTodos.length > 0) {
      ctxLines.push(
        `- To-Do belum selesai (${pendingTodos.length}): ${pendingTodos
          .slice(0, 6)
          .map((t) => t.title)
          .join('; ')}`
      );
    }

    if (s.scratchpadText.trim()) {
      ctxLines.push(`- Cuplikan Scratchpad Notes: ${s.scratchpadText.trim().slice(0, 180)}`);
    }

    if (s.droppedItems.length > 0) {
      ctxLines.push(
        `- File di Tray saat ini: ${s.droppedItems
          .slice(0, 4)
          .map((i) => `${i.name} (${i.badgeText})`)
          .join(', ')}`
      );
    }

    if (s.timer.isRunning) {
      ctxLines.push(`- Timer Fokus sedang jalan (${s.timer.formattedTime} tersisa)`);
    }

    ctxLines.push(
      `- Sistem Windows: CPU ${s.system.cpuPercent}%, RAM ${s.system.ramUsedGB}/${s.system.ramTotalGB} GB`
    );

    if (s.cacheCleaner && s.cacheCleaner.hasCompletedInitialScan) {
      ctxLines.push(
        `- Pembersih Cache Windows (Maki Clean): Terdeteksi ${s.cacheCleaner.formattedSafeSize} sampah cache aman (Temp, Chrome/Edge, npm). Maki bisa membersihkannya kapan saja via tombol sapu 🧹 di dock desktop atau tab System.`
      );
    }

    const appKnowledge = [
      'Pengetahuan tentang dirimu & aplikasi maki-land (jelaskan HANYA bila pengguna bertanya "kamu apa", "ini aplikasi apa", "fitur apa saja", cara pakai, dsb. Jangan mengarang fitur di luar daftar ini):',
      '- maki-land adalah aplikasi Dynamic Island interaktif di tengah atas layar Windows dengan maskot capybara bernama Maki yang hidup. Maki juga bisa keluar dan berkeliaran di Desktop. Gratis & open source (MIT License). Tersedia untuk Windows 10/11 dan macOS.',
      '- Tanya Maki (kamu sendiri): asisten AI pintar yang mendukung berbagai provider AI: Google Gemini, Groq (Llama 3.3 kilat & gratis), OpenAI (GPT-4o), DeepSeek (V3 & R1 hemat), OpenRouter (multi-model hub), Anthropic (Claude 3.5), dan Ollama (100% lokal & offline tanpa internet). Bisa tanya apa saja (jadwal, kode, ide, rangkuman, status sistem, pembersih cache), melampirkan screenshot/gambar untuk dijelaskan (tombol kamera 📸, paste, atau drag & drop file; screenshot bisa diambil dengan Win+Shift+S), memilih model AI lewat dropdown di header, tombol "Salin Jawaban" untuk menyalin jawaban, tombol "Batal" untuk menghentikan jawaban, tombol obrolan baru ↺, dan pengaturan API Key 🔑 (disimpan lokal di PC pengguna). Kamu juga tahu konteks live aplikasi: lagu, jadwal, To-Do, file di Tray, timer, statistik sistem, dan cache.',
      '- Pembersih Cache Aman (Maki Clean): memindai dan membersihkan sampah cache Windows dengan aman (hanya dipindahkan ke Recycle Bin Windows, tidak pernah menghapus permanen secara berbahaya). Bisa diakses lewat tombol sapu 🧹 di dock desktop, tab System di Dynamic Island, atau langsung minta ke kamu di chat Tanya Maki.',
      '- Maki di Desktop: bisa diseret, diklik untuk dielus, klik dua kali untuk atraksi, jalan-jalan sendiri, mengejar kursor, dikasih jeruk, berendam di onsen, sapu-sapu cache 🧹, atau pulang ke notch. Ada dock kecil saat kursor di dekat Maki: 💬 Tanya Maki, 📸 ambil screenshot ke Tray, 🎪 atraksi acak, 🐾 main kejar kursor, 🍊 kasih jeruk, ♨️ onsen, 🧹 sapu cache aman, 🚶/📌 bebas jalan atau kunci posisi, 🏠 pulang ke notch. Maki punya status mood & kenyang serta level, dan tampilan maskot (klasik atau boneka).',
      '- Tab di Dynamic Island: maki-land (ringkasan: musik, kalender, baterai), Capy (habitat Maki + Tanya AI), Notes (Scratchpad + To-Do + pintasan), Launch (peluncur cepat aplikasi & web favorit), Tray (tempat menaruh file/screenshot + PDF Studio: convert & kompres, edit & pisah halaman, watermark & kunci), System (CPU, RAM, jaringan + Pembersih Cache Aman 🧹), Clipboard (riwayat salinan, tinggal paste), Timer (timer fokus dengan notifikasi saat selesai).',
      '- Maki juga bisa menerima file yang di-drag ke mulutnya atau ke notch.',
    ].join('\n');

    return [
      'Kamu adalah Maki, maskot capybara kecil yang santai, cerdas, hangat, dan tinggal di Dynamic Island / Desktop Windows pengguna (aplikasi maki-land).',
      'Gaya bicaramu:',
      '- Gunakan Bahasa Indonesia sehari-hari yang natural, akrab, kalem, dan enak dibaca (kecuali pengguna bertanya dalam bahasa lain).',
      '- Jangan terdengar kaku/robotik dan jangan berlebihan memakai tanda seru atau emoji (cukup sesekali jika pas).',
      '- Jawab langsung ke inti, ringkas, jelas, dan akurat. Jika diminta menjelaskan kode, gambar/screenshot, dokumen, atau ide, jelaskan dengan rapi dan mudah dipahami.',
      '- Kamu punya akses ke konteks live maki-land di bawah ini; gunakan hanya saat relevan dengan pertanyaan pengguna:',
      ctxLines.join('\n'),
      '',
      appKnowledge,
    ].join('\n');
  }

  public static shortBubblePreview(fullText: string): string {
    const firstLine =
      fullText
        .replace(/\*\*/g, '')
        .replace(/`/g, '')
        .split(/\r?\n/)
        .map((l) => l.trim())
        .find((l) => l.length > 0) || 'udah kujawab ya!';
    if (firstLine.length <= 42) return firstLine;
    return `${firstLine.slice(0, 39).trim()}...`;
  }
}
