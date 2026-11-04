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
    return () => {
      mounted = false;
      unsub();
    };
  }, []);

  return state;
}
