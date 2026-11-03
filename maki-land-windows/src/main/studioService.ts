import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { app, clipboard, dialog, nativeImage, shell, BrowserWindow } from 'electron';
import { PDFDocument, degrees, rgb, StandardFonts } from 'pdf-lib';
import JSZip from 'jszip';
import { DroppedItem, DroppedItemKind } from '../shared/types';
import { copyFileToWindowsClipboard } from './windowsSystemBridge';

const IMAGE_EXTS = new Set(['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif']);

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function detectKind(filePath: string): { kind: DroppedItemKind; badge: string } {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.pdf') return { kind: 'pdf', badge: 'PDF' };
  if (IMAGE_EXTS.has(ext)) return { kind: 'image', badge: ext.replace('.', '').toUpperCase() || 'IMG' };
  const clean = ext.replace('.', '').toUpperCase();
  return { kind: 'other', badge: clean || 'FILE' };
}

export class StudioService {
  private items: DroppedItem[] = [];
  private activeStudioId: string | null = null;
  private isBusy = false;
  private banner: { message: string; isError: boolean } | null = null;
  private bannerTimer: NodeJS.Timeout | null = null;
  private onChange: () => void;

  constructor(onChange: () => void) {
    this.onChange = onChange;
  }

  public getSnapshot() {
    return {
      droppedItems: this.items,
      activeStudioItemId: this.activeStudioId,
      trayBusy: this.isBusy,
      trayBanner: this.banner,
    };
  }

  public setActiveStudioItem(id: string | null) {
    this.activeStudioId = id;
    this.onChange();
  }

  public showBanner(message: string, isError = false, durationMs = 3400) {
    if (this.bannerTimer) clearTimeout(this.bannerTimer);
    this.banner = { message, isError };
    this.onChange();
    this.bannerTimer = setTimeout(() => {
      this.banner = null;
      this.onChange();
    }, durationMs);
  }

  private getCapturesDir(): string {
    const dir = path.join(app.getPath('userData'), 'TrayCaptures');
    fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  private getStudioOutputDir(): string {
    const docs = app.getPath('documents') || os.homedir();
    const dir = path.join(docs, 'maki-land Studio');
    fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  public async addFilePaths(paths: string[], openFirstInStudio = false): Promise<DroppedItem[]> {
    const added: DroppedItem[] = [];
    for (const rawPath of paths) {
      if (!rawPath) continue;
      try {
        const stat = fs.statSync(rawPath);
        if (!stat.isFile()) continue;

        const existing = this.items.find((x) => x.path === rawPath);
        if (existing) {
          added.push(existing);
          continue;
        }

        const { kind, badge } = detectKind(rawPath);
        let thumbnailDataUrl: string | undefined;
        let pageCount: number | undefined;

        if (kind === 'image') {
          const img = nativeImage.createFromPath(rawPath);
          if (!img.isEmpty()) {
            const resized = img.resize({ width: 120 });
            thumbnailDataUrl = resized.toDataURL();
          }
        } else if (kind === 'pdf') {
          try {
            const buf = fs.readFileSync(rawPath);
            const doc = await PDFDocument.load(buf, { ignoreEncryption: true });
            pageCount = doc.getPageCount();
          } catch {
            pageCount = undefined;
          }
        } else {
          try {
            const icon = await app.getFileIcon(rawPath, { size: 'normal' });
            if (!icon.isEmpty()) {
              thumbnailDataUrl = icon.toDataURL();
            }
          } catch {
            // ignore
          }
        }

        const item: DroppedItem = {
          id: crypto.randomUUID(),
          name: path.basename(rawPath),
          path: rawPath,
          sizeBytes: stat.size,
          sizeFormatted: formatBytes(stat.size),
          kind,
          badgeText: pageCount ? `PDF • ${pageCount} hal` : badge,
          thumbnailDataUrl,
          pageCount,
        };
        this.items.unshift(item);
        added.push(item);
      } catch {
        // skip unreadable file
      }
    }

    if (this.items.length > 32) {
      this.items = this.items.slice(0, 32);
    }

    if (openFirstInStudio && added.length > 0) {
      this.activeStudioId = added[0].id;
    }

    this.onChange();
    return added;
  }

  public saveClipboardImageToFile(): string | null {
    const img = clipboard.readImage();
    if (img.isEmpty()) return null;
    const size = img.getSize();
    if (size.width < 4 || size.height < 4) return null;

    const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const outPath = path.join(this.getCapturesDir(), `Screenshot-${stamp}.png`);
    fs.writeFileSync(outPath, img.toPNG());
    return outPath;
  }

  public findLatestRecentScreenshotFile(): string | null {
    const home = os.homedir();
    const candidatesDirs = [
      path.join(home, 'Pictures', 'Screenshots'),
      path.join(home, 'OneDrive', 'Pictures', 'Screenshots'),
      path.join(home, 'Desktop'),
      path.join(home, 'Downloads'),
    ];

    let newestPath: string | null = null;
    let newestMtime = Date.now() - 1000 * 60 * 60 * 12; // within last 12 hours

    for (const dir of candidatesDirs) {
      if (!fs.existsSync(dir)) continue;
      try {
        const files = fs.readdirSync(dir);
        for (const f of files) {
          const ext = path.extname(f).toLowerCase();
          if (!IMAGE_EXTS.has(ext)) continue;
          const lower = f.toLowerCase();
          const isScreenshotsFolder = dir.toLowerCase().includes('screenshots');
          if (
            !isScreenshotsFolder &&
            !lower.includes('screenshot') &&
            !lower.includes('cuplikan') &&
            !lower.includes('snip') &&
            !lower.includes('capture')
          ) {
            continue;
          }
          const full = path.join(dir, f);
          const st = fs.statSync(full);
          if (st.isFile() && st.mtimeMs > newestMtime) {
            newestMtime = st.mtimeMs;
            newestPath = full;
          }
        }
      } catch {
        // ignore folder permission error
      }
    }
    return newestPath;
  }

  public async grabClipboardOrRecentScreenshot(): Promise<DroppedItem | null> {
    const clipFile = this.saveClipboardImageToFile();
    if (clipFile) {
      const added = await this.addFilePaths([clipFile], false);
      if (added[0]) {
        this.showBanner('Screenshot Clipboard masuk Tray!');
        return added[0];
      }
    }
    const recent = this.findLatestRecentScreenshotFile();
    if (recent) {
      const added = await this.addFilePaths([recent], false);
      if (added[0]) {
        this.showBanner('Screenshot terbaru masuk Tray!');
        return added[0];
      }
    }
    return null;
  }

  public async pickFilesDialog(parent?: BrowserWindow | null): Promise<DroppedItem[]> {
    const res = await dialog.showOpenDialog(parent || BrowserWindow.getAllWindows()[0], {
      title: 'Pilih File atau Gambar untuk Tray maki-land',
      properties: ['openFile', 'multiSelections'],
    });
    if (res.canceled || res.filePaths.length === 0) return [];
    return this.addFilePaths(res.filePaths, false);
  }

  public async copyItemToClipboard(id: string): Promise<boolean> {
    const item = this.items.find((x) => x.id === id);
    if (!item || !fs.existsSync(item.path)) return false;

    if (item.kind === 'image') {
      const img = nativeImage.createFromPath(item.path);
      if (!img.isEmpty()) {
        clipboard.writeImage(img);
        this.showBanner(`Gambar "${item.name}" disalin!`);
        return true;
      }
    }

    if (process.platform === 'win32') {
      await copyFileToWindowsClipboard(item.path);
      this.showBanner(`File "${item.name}" disalin ke Clipboard!`);
      return true;
    }

    clipboard.writeText(item.path);
    this.showBanner(`Path "${item.name}" disalin!`);
    return true;
  }

  public removeItem(id: string) {
    this.items = this.items.filter((x) => x.id !== id);
    if (this.activeStudioId === id) {
      this.activeStudioId = null;
    }
    this.onChange();
  }

  public clearAll() {
    this.items = [];
    this.activeStudioId = null;
    this.onChange();
  }

  public revealItem(id: string) {
    const item = this.items.find((x) => x.id === id);
    if (item && fs.existsSync(item.path)) {
      shell.showItemInFolder(item.path);
    }
  }

  public openItem(id: string) {
    const item = this.items.find((x) => x.id === id);
    if (item && fs.existsSync(item.path)) {
      void shell.openPath(item.path);
    }
  }

  public renameItem(id: string, newBaseName: string): boolean {
    const item = this.items.find((x) => x.id === id);
    if (!item || !fs.existsSync(item.path)) return false;
    const trimmed = newBaseName.trim();
    if (!trimmed) return false;

    const ext = path.extname(item.path);
    const finalName = trimmed.toLowerCase().endsWith(ext.toLowerCase()) ? trimmed : `${trimmed}${ext}`;
    const targetPath = path.join(path.dirname(item.path), finalName);
    try {
      fs.renameSync(item.path, targetPath);
      item.path = targetPath;
      item.name = finalName;
      this.showBanner(`Nama diubah ke ${finalName}`);
      this.onChange();
      return true;
    } catch {
      this.showBanner('Gagal mengubah nama file', true);
      return false;
    }
  }

  // --- Offline PDF & Image Studio ---

  public async mergeItemsToPdf(ids?: string[]): Promise<DroppedItem | null> {
    const pool = ids && ids.length > 0 ? this.items.filter((i) => ids.includes(i.id)) : this.items;
    const mergeable = pool.filter((i) => i.kind === 'pdf' || i.kind === 'image');
    if (mergeable.length < 2) {
      this.showBanner('Pilih minimal 2 PDF/Gambar untuk digabung', true);
      return null;
    }

    this.isBusy = true;
    this.onChange();
    try {
      const outDoc = await PDFDocument.create();
      for (const item of mergeable) {
        if (!fs.existsSync(item.path)) continue;
        if (item.kind === 'pdf') {
          const srcBytes = fs.readFileSync(item.path);
          const srcDoc = await PDFDocument.load(srcBytes, { ignoreEncryption: true });
          const pages = await outDoc.copyPages(srcDoc, srcDoc.getPageIndices());
          pages.forEach((p) => outDoc.addPage(p));
        } else if (item.kind === 'image') {
          const img = nativeImage.createFromPath(item.path);
          if (img.isEmpty()) continue;
          const pngBytes = img.toPNG();
          const embedded = await outDoc.embedPng(pngBytes);
          const { width, height } = embedded.scale(1);
          const page = outDoc.addPage([width, height]);
          page.drawImage(embedded, { x: 0, y: 0, width, height });
        }
      }

      const pdfBytes = await outDoc.save();
      const outPath = path.join(this.getStudioOutputDir(), `Gabungan-${Date.now()}.pdf`);
      fs.writeFileSync(outPath, pdfBytes);
      const added = await this.addFilePaths([outPath], true);
      this.showBanner(`Berhasil digabung (${outDoc.getPageCount()} halaman)!`);
      return added[0] || null;
    } catch (e) {
      this.showBanner(`Gagal gabung PDF: ${(e as Error).message}`, true);
      return null;
    } finally {
      this.isBusy = false;
      this.onChange();
    }
  }

  public async rotatePdf(id: string, angleDeg: 90 | 180 | 270): Promise<DroppedItem | null> {
    const item = this.items.find((x) => x.id === id);
    if (!item || item.kind !== 'pdf' || !fs.existsSync(item.path)) return null;

    this.isBusy = true;
    this.onChange();
    try {
      const doc = await PDFDocument.load(fs.readFileSync(item.path), { ignoreEncryption: true });
      for (const page of doc.getPages()) {
        const cur = page.getRotation().angle;
        page.setRotation(degrees((cur + angleDeg) % 360));
      }
      const base = path.basename(item.name, '.pdf');
      const outPath = path.join(this.getStudioOutputDir(), `${base}-rot${angleDeg}.pdf`);
      fs.writeFileSync(outPath, await doc.save());
      const added = await this.addFilePaths([outPath], true);
      this.showBanner(`PDF diputar ${angleDeg}°!`);
      return added[0] || null;
    } catch {
      this.showBanner('Gagal memutar PDF', true);
      return null;
    } finally {
      this.isBusy = false;
      this.onChange();
    }
  }

  public async splitPdf(id: string, rangeSpec: string): Promise<DroppedItem | null> {
    const item = this.items.find((x) => x.id === id);
    if (!item || item.kind !== 'pdf' || !fs.existsSync(item.path)) return null;

    this.isBusy = true;
    this.onChange();
    try {
      const srcDoc = await PDFDocument.load(fs.readFileSync(item.path), { ignoreEncryption: true });
      const total = srcDoc.getPageCount();
      const indices: number[] = [];

      for (const part of rangeSpec.split(',')) {
        const trimmed = part.trim();
        if (!trimmed) continue;
        if (trimmed.includes('-')) {
          const [a, b] = trimmed.split('-').map((n) => parseInt(n.trim(), 10));
          if (!isNaN(a) && !isNaN(b)) {
            const start = Math.max(1, Math.min(a, b));
            const end = Math.min(total, Math.max(a, b));
            for (let p = start; p <= end; p++) indices.push(p - 1);
          }
        } else {
          const p = parseInt(trimmed, 10);
          if (!isNaN(p) && p >= 1 && p <= total) indices.push(p - 1);
        }
      }

      if (indices.length === 0) {
        this.showBanner(`Rentang halaman tidak valid (1-${total})`, true);
        return null;
      }

      const outDoc = await PDFDocument.create();
      const copied = await outDoc.copyPages(srcDoc, indices);
      copied.forEach((p) => outDoc.addPage(p));

      const base = path.basename(item.name, '.pdf');
      const outPath = path.join(this.getStudioOutputDir(), `${base}-hal-${rangeSpec.replace(/[^0-9,-]/g, '')}.pdf`);
      fs.writeFileSync(outPath, await outDoc.save());
      const added = await this.addFilePaths([outPath], true);
      this.showBanner(`Diekstrak ${indices.length} halaman!`);
      return added[0] || null;
    } catch {
      this.showBanner('Gagal memotong PDF', true);
      return null;
    } finally {
      this.isBusy = false;
      this.onChange();
    }
  }

  public async watermarkPdf(id: string, text: string): Promise<DroppedItem | null> {
    const item = this.items.find((x) => x.id === id);
    const cleanText = text.trim() || 'CONFIDENTIAL';
    if (!item || item.kind !== 'pdf' || !fs.existsSync(item.path)) return null;

    this.isBusy = true;
    this.onChange();
    try {
      const doc = await PDFDocument.load(fs.readFileSync(item.path), { ignoreEncryption: true });
      const font = await doc.embedFont(StandardFonts.HelveticaBold);

      for (const page of doc.getPages()) {
        const { width, height } = page.getSize();
        const fontSize = Math.max(24, Math.min(width, height) * 0.075);
        page.drawText(cleanText, {
          x: width * 0.18,
          y: height * 0.42,
          size: fontSize,
          font,
          color: rgb(0.75, 0.2, 0.2),
          opacity: 0.22,
          rotate: degrees(32),
        });
      }

      const base = path.basename(item.name, '.pdf');
      const outPath = path.join(this.getStudioOutputDir(), `${base}-watermark.pdf`);
      fs.writeFileSync(outPath, await doc.save());
      const added = await this.addFilePaths([outPath], true);
      this.showBanner('Watermark berhasil ditambahkan!');
      return added[0] || null;
    } catch {
      this.showBanner('Gagal memberi watermark PDF', true);
      return null;
    } finally {
      this.isBusy = false;
      this.onChange();
    }
  }

  public async convertImageFormat(id: string, format: 'png' | 'jpg'): Promise<DroppedItem | null> {
    const item = this.items.find((x) => x.id === id);
    if (!item || item.kind !== 'image' || !fs.existsSync(item.path)) return null;

    this.isBusy = true;
    this.onChange();
    try {
      const img = nativeImage.createFromPath(item.path);
      if (img.isEmpty()) {
        this.showBanner('Gagal membaca gambar', true);
        return null;
      }
      const base = path.basename(item.name, path.extname(item.name));
      const outPath = path.join(this.getStudioOutputDir(), `${base}-converted.${format}`);
      const buf = format === 'png' ? img.toPNG() : img.toJPEG(90);
      fs.writeFileSync(outPath, buf);
      const added = await this.addFilePaths([outPath], true);
      this.showBanner(`Dikonversi ke ${format.toUpperCase()}!`);
      return added[0] || null;
    } catch {
      this.showBanner('Gagal mengonversi gambar', true);
      return null;
    } finally {
      this.isBusy = false;
      this.onChange();
    }
  }

  public async zipAllItems(): Promise<DroppedItem | null> {
    if (this.items.length === 0) return null;
    this.isBusy = true;
    this.onChange();
    try {
      const zip = new JSZip();
      for (const item of this.items) {
        if (fs.existsSync(item.path)) {
          zip.file(item.name, fs.readFileSync(item.path));
        }
      }
      const buf = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
      const outPath = path.join(this.getStudioOutputDir(), `maki-tray-${Date.now()}.zip`);
      fs.writeFileSync(outPath, buf);
      const added = await this.addFilePaths([outPath], false);
      this.showBanner(`Arsip ZIP siap (${this.items.length - 1} file)!`);
      return added[0] || null;
    } catch {
      this.showBanner('Gagal membuat ZIP', true);
      return null;
    } finally {
      this.isBusy = false;
      this.onChange();
    }
  }
}
