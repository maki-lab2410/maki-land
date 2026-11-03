import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { shell } from 'electron';
import { CacheCleanerState } from '../shared/types';

export interface WindowsCacheCategory {
  id: string;
  name: string;
  description: string;
  paths: string[];
}

export class WindowsCacheCleanerService {
  private static instance: WindowsCacheCleanerService | null = null;

  public state: CacheCleanerState = {
    isScanning: false,
    isCleaning: false,
    totalSafeBytes: 0,
    formattedSafeSize: '0 KB',
    lastFreedBytes: 0,
    formattedFreedSize: '0 KB',
    progressText: '',
    hasCompletedInitialScan: false,
  };

  private onChangeCallback: (() => void) | null = null;

  private constructor() {
    // Schedule quick initial scan shortly after startup
    setTimeout(() => {
      void this.startScan();
    }, 4000);
  }

  public static getInstance(): WindowsCacheCleanerService {
    if (!WindowsCacheCleanerService.instance) {
      WindowsCacheCleanerService.instance = new WindowsCacheCleanerService();
    }
    return WindowsCacheCleanerService.instance;
  }

  public setOnChange(cb: () => void) {
    this.onChangeCallback = cb;
  }

  private notify() {
    if (this.onChangeCallback) {
      this.onChangeCallback();
    }
  }

  public formatBytes(bytes: number): string {
    if (bytes <= 0) return '0 KB';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let v = bytes;
    let idx = 0;
    while (v >= 1024 && idx < units.length - 1) {
      v /= 1024;
      idx++;
    }
    return `${v.toFixed(idx === 0 ? 0 : 1)} ${units[idx]}`;
  }

  private getSafeTargetDirs(): string[] {
    const home = os.homedir();
    const localAppData = process.env.LOCALAPPDATA || path.join(home, 'AppData', 'Local');
    const tempDir = os.tmpdir();

    const targets: string[] = [
      tempDir,
      path.join(localAppData, 'Temp'),
      path.join(localAppData, 'CrashDumps'),
      path.join(localAppData, 'Google', 'Chrome', 'User Data', 'Default', 'Cache', 'Cache_Data'),
      path.join(localAppData, 'Google', 'Chrome', 'User Data', 'Default', 'Code Cache'),
      path.join(localAppData, 'Microsoft', 'Edge', 'User Data', 'Default', 'Cache', 'Cache_Data'),
      path.join(localAppData, 'Microsoft', 'Edge', 'User Data', 'Default', 'Code Cache'),
      path.join(home, '.npm', '_cacache'),
    ];

    // Filter to existing directories
    return targets.filter((dir) => {
      try {
        return fs.existsSync(dir) && fs.statSync(dir).isDirectory();
      } catch {
        return false;
      }
    });
  }

  private async calculateDirSize(dirPath: string, maxDepth = 3, currentDepth = 0): Promise<number> {
    if (currentDepth > maxDepth) return 0;
    let total = 0;
    try {
      const entries = await fs.promises.readdir(dirPath, { withFileTypes: true });
      for (const entry of entries) {
        const full = path.join(dirPath, entry.name);
        try {
          if (entry.isDirectory()) {
            total += await this.calculateDirSize(full, maxDepth, currentDepth + 1);
          } else if (entry.isFile()) {
            const st = await fs.promises.stat(full);
            total += st.size;
          }
        } catch {
          // Skip inaccessible or locked files
        }
      }
    } catch {
      // Skip inaccessible directories
    }
    return total;
  }

  public async startScan(): Promise<void> {
    if (this.state.isScanning || this.state.isCleaning) return;

    this.state.isScanning = true;
    this.state.progressText = 'Memindai cache aman...';
    this.notify();

    const targets = this.getSafeTargetDirs();
    let safeSum = 0;

    for (let i = 0; i < targets.length; i++) {
      const target = targets[i];
      const baseName = path.basename(target);
      this.state.progressText = `Memindai (${i + 1}/${targets.length}): ${baseName}`;
      this.notify();

      const size = await this.calculateDirSize(target);
      safeSum += size;
    }

    this.state.totalSafeBytes = safeSum;
    this.state.formattedSafeSize = this.formatBytes(safeSum);
    this.state.isScanning = false;
    this.state.hasCompletedInitialScan = true;
    this.state.progressText = '';
    this.notify();
  }

  public async cleanSafeCache(onStep?: (msg: string) => void): Promise<{ freedBytes: number; count: number }> {
    if (this.state.isCleaning) {
      return { freedBytes: 0, count: 0 };
    }

    this.state.isCleaning = true;
    this.state.progressText = 'Menyiapkan pembersihan...';
    this.notify();

    const targets = this.getSafeTargetDirs();
    let freedBytes = 0;
    let count = 0;

    for (let i = 0; i < targets.length; i++) {
      const target = targets[i];
      const baseName = path.basename(target);
      const stepMsg = `Membersihkan (${i + 1}/${targets.length}): ${baseName}`;
      this.state.progressText = stepMsg;
      if (onStep) onStep(stepMsg);
      this.notify();

      try {
        const entries = await fs.promises.readdir(target, { withFileTypes: true });
        for (const entry of entries) {
          const itemPath = path.join(target, entry.name);
          try {
            let itemSize = 0;
            if (entry.isFile()) {
              const st = await fs.promises.stat(itemPath);
              itemSize = st.size;
            } else if (entry.isDirectory()) {
              itemSize = await this.calculateDirSize(itemPath, 2);
            }

            // Move safely to Windows Recycle Bin via electron shell API
            await shell.trashItem(itemPath);
            freedBytes += itemSize;
            count++;
          } catch {
            // In Windows, files actively held open by applications cannot be trashed. Skip silently.
          }
        }
      } catch {
        // Skip directory if readdir fails
      }
    }

    this.state.lastFreedBytes = freedBytes;
    this.state.formattedFreedSize = this.formatBytes(freedBytes);
    this.state.isCleaning = false;
    this.state.progressText = '';
    this.notify();

    // Re-scan to update remaining sizes
    await this.startScan();

    return { freedBytes, count };
  }
}
