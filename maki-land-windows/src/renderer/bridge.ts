import { useEffect, useState } from 'react';
import { SharedAppState } from '../shared/types';

export interface MakiWindowBridge {
  getState: () => Promise<SharedAppState>;
  onStateChange: (cb: (state: SharedAppState) => void) => () => void;
  dispatch: (action: string, payload?: Record<string, unknown>) => Promise<SharedAppState>;
  prepareNativeDrag: () => void;
  startNativeFileDrag: (filePath: string) => void;
  endNativeFileDrag: () => void;
  saveVoiceRecording: (
    base64Data: string,
    durationSec: number,
    mimeType?: string
  ) => Promise<{ success: boolean; filePath?: string; fileName?: string; error?: string }>;
  saveCameraPhoto: (
    base64Data: string
  ) => Promise<{ success: boolean; filePath?: string; fileName?: string; error?: string }>;
  setCompactHover: (hovering: boolean) => void;
  setDropHold: (holding: boolean) => void;
  desktopDragStart: (screenX: number, screenY: number) => void;
  desktopDragMove: (screenX: number, screenY: number) => void;
  desktopDragEnd: (screenX: number, screenY: number) => void;
  showDesktopContextMenu: () => void;
  companionDragStart: (screenX: number, screenY: number) => void;
  companionDragMove: (screenX: number, screenY: number) => void;
  companionDragEnd: (screenX: number, screenY: number) => void;
  showCompanionContextMenu: () => void;
  getPathForFile: (file: File) => string;
}

declare global {
  interface Window {
    maki: MakiWindowBridge;
  }
}

export function dispatchMaki(action: string, payload?: Record<string, unknown>) {
  return window.maki.dispatch(action, payload);
}

export function extractDroppedFilePaths(e: React.DragEvent): string[] {
  const files = Array.from(e.dataTransfer?.files || []);
  const paths: string[] = [];
  for (const f of files) {
    const p = window.maki.getPathForFile(f);
    if (p) paths.push(p);
  }
  return paths;
}

export function useMakiState(): SharedAppState | null {
  const [state, setState] = useState<SharedAppState | null>(null);

  useEffect(() => {
    let mounted = true;
    window.maki.getState().then((s) => {
      if (mounted) setState(s);
    });
    const unsub = window.maki.onStateChange((next) => {
      if (mounted) setState(next);
    });

    // Realtime Native Chromium Battery Telemetry (Zero-latency Windows OS power integration)
    let batteryInstance: any = null;
    const syncBattery = () => {
      if (!mounted || !batteryInstance) return;
      const level = Math.max(0, Math.min(100, Math.round((batteryInstance.level ?? 1) * 100)));
      const isCharging = Boolean(batteryInstance.charging);

      // Optimistic local state update for zero-latency UI refresh
      setState((prev) => {
        if (!prev) return prev;
        if (prev.system.batteryLevel === level && prev.system.isCharging === isCharging) {
          return prev;
        }
        return {
          ...prev,
          system: {
            ...prev.system,
            batteryLevel: level,
            isCharging,
            hasBattery: true,
          },
        };
      });

      // Synchronize with Electron Main process and all windows
      window.maki.dispatch('reportBattery', {
        level,
        isCharging,
        hasBattery: true,
      }).catch(() => {});
    };

    if (typeof navigator !== 'undefined' && 'getBattery' in navigator) {
      (navigator as any).getBattery().then((b: any) => {
        if (!mounted) return;
        batteryInstance = b;
        syncBattery();
        b.addEventListener('levelchange', syncBattery);
        b.addEventListener('chargingchange', syncBattery);
      }).catch(() => {});
    }

    return () => {
      mounted = false;
      unsub();
      if (batteryInstance) {
        batteryInstance.removeEventListener('levelchange', syncBattery);
        batteryInstance.removeEventListener('chargingchange', syncBattery);
      }
    };
  }, []);

  return state;
}
