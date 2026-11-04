import { contextBridge, ipcRenderer, webUtils } from 'electron';

export const makiBridge = {
  getState: () => ipcRenderer.invoke('maki:get-state'),
  onStateChange: (cb: (state: unknown) => void) => {
    const listener = (_ev: Electron.IpcRendererEvent, state: unknown) => cb(state);
    ipcRenderer.on('maki:state', listener);
    return () => ipcRenderer.removeListener('maki:state', listener);
  },
  dispatch: (action: string, payload?: unknown) => ipcRenderer.invoke('maki:dispatch', action, payload),
  prepareNativeDrag: () => ipcRenderer.send('maki:prepare-drag'),
  startNativeFileDrag: (filePath: string) => ipcRenderer.send('maki:start-drag', filePath),
  endNativeFileDrag: () => ipcRenderer.send('maki:end-drag'),
  saveVoiceRecording: (base64Data: string, durationSec: number, mimeType?: string) =>
    ipcRenderer.invoke('maki:save-voice-recording', { base64Data, durationSec, mimeType }),
  setCompactHover: (hovering: boolean) => ipcRenderer.send('maki:compact-hover', hovering),
  setDropHold: (holding: boolean) => ipcRenderer.send('maki:drop-hold', holding),
  desktopDragStart: (screenX: number, screenY: number) =>
    ipcRenderer.send('maki:desktop-drag-start', { screenX, screenY }),
  desktopDragMove: (screenX: number, screenY: number) =>
    ipcRenderer.send('maki:desktop-drag-move', { screenX, screenY }),
  desktopDragEnd: (screenX: number, screenY: number) =>
    ipcRenderer.send('maki:desktop-drag-end', { screenX, screenY }),
  showDesktopContextMenu: () => ipcRenderer.send('maki:desktop-context-menu'),
  companionDragStart: (screenX: number, screenY: number) =>
    ipcRenderer.send('maki:companion-drag-start', { screenX, screenY }),
  companionDragMove: (screenX: number, screenY: number) =>
    ipcRenderer.send('maki:companion-drag-move', { screenX, screenY }),
  companionDragEnd: (screenX: number, screenY: number) =>
    ipcRenderer.send('maki:companion-drag-end', { screenX, screenY }),
  showCompanionContextMenu: () => ipcRenderer.send('maki:companion-context-menu'),
  getPathForFile: (file: File): string => {
    try {
      return webUtils.getPathForFile(file) || '';
    } catch {
      return (file as unknown as { path?: string }).path || '';
    }
  },
};

contextBridge.exposeInMainWorld('maki', makiBridge);
