import React, { useEffect, useRef, useState } from 'react';
import {
  ALL_ISLAND_TABS,
  computeTargetIslandSize,
  ISLAND_CANVAS_HEIGHT,
  ISLAND_CANVAS_WIDTH,
  IslandTab,
} from '../shared/types';
import { dispatchMaki, extractDroppedFilePaths, useMakiState } from './bridge';
import { Capybara2DCanvas } from './components/Capybara2DCanvas';
import { CapySpeechBubble, ContextualCapyCard } from './components/CapySpeechBubble';
import { OnboardingModal } from './components/OnboardingModal';
import {
  AudioWaveform,
  CameraMirrorModal,
  CapyHabitatTab,
  ClipboardTab,
  LauncherTab,
  MakiLandTab,
  NotesTab,
  SystemTab,
  TimerTab,
  TrayTab,
  VoiceRecorderPanel,
} from './tabs/AllTabs';

function buildNotchSvgPath(w: number, h: number, bottomRadius: number, earRadius: number): string {
  const safeW = Math.max(w || 226, 40);
  const safeH = Math.max(h || 32, 20);
  const bRad = Math.max(2, Math.min(bottomRadius || 14, safeH / 2));
  const eRad = Math.max(2, Math.min(earRadius || 8, (safeW - bRad * 2) / 4));
  return [
    `M 0 0`,
    `A ${eRad} ${eRad} 0 0 1 ${eRad} ${eRad}`,
    `L ${eRad} ${safeH - bRad}`,
    `A ${bRad} ${bRad} 0 0 0 ${eRad + bRad} ${safeH}`,
    `L ${safeW - eRad - bRad} ${safeH}`,
    `A ${bRad} ${bRad} 0 0 0 ${safeW - eRad} ${safeH - bRad}`,
    `L ${safeW - eRad} ${eRad}`,
    `A ${eRad} ${eRad} 0 0 1 ${safeW} 0`,
    `Z`,
  ].join(' ');
}

function useAnimatedNotch(
  targetW: number,
  targetH: number,
  targetBRad: number,
  targetERad: number
) {
  const [current, setCurrent] = useState({
    w: targetW,
    h: targetH,
    bRad: targetBRad,
    eRad: targetERad,
  });

  const stateRef = useRef(current);
  stateRef.current = current;

  useEffect(() => {
    let rafId: number;
    const startW = stateRef.current.w;
    const startH = stateRef.current.h;
    const startB = stateRef.current.bRad;
    const startE = stateRef.current.eRad;

    if (
      Math.abs(startW - targetW) < 0.5 &&
      Math.abs(startH - targetH) < 0.5 &&
      Math.abs(startB - targetBRad) < 0.2 &&
      Math.abs(startE - targetERad) < 0.2
    ) {
      setCurrent({ w: targetW, h: targetH, bRad: targetBRad, eRad: targetERad });
      return;
    }

    const startTime = performance.now();
    const duration = 260; // Snappy Apple Dynamic Island top-to-bottom bloom

    const tick = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.min(1, elapsed / duration);
      // Apple-style spring easing cubic-bezier(0.16, 1, 0.3, 1)
      const t1 = 1 - progress;
      const ease = 1 - t1 * t1 * t1;

      const nextW = startW + (targetW - startW) * ease;
      const nextH = startH + (targetH - startH) * ease;
      const nextB = startB + (targetBRad - startB) * ease;
      const nextE = startE + (targetERad - startE) * ease;

      setCurrent({
        w: nextW,
        h: nextH,
        bRad: nextB,
        eRad: nextE,
      });

      if (progress < 1) {
        rafId = requestAnimationFrame(tick);
      }
    };

    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, [targetW, targetH, targetBRad, targetERad]);

  return current;
}

export const IslandApp: React.FC = () => {
  const state = useMakiState();
  const [activeTab, setActiveTab] = useState<IslandTab>(state?.selectedTab || 'maki-land');
  const [isVoiceRecorderOpen, setIsVoiceRecorderOpen] = useState(false);
  const [compactHover, setCompactHover] = useState(false);
  const [clock, setClock] = useState(() =>
    new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
  );

  // Synchronize optimistic local tab state whenever the backend tab state changes
  useEffect(() => {
    if (state?.selectedTab && state.selectedTab !== activeTab) {
      setActiveTab(state.selectedTab);
    }
  }, [state?.selectedTab]);

  useEffect(() => {
    const id = setInterval(() => {
      setClock(new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }));
    }, 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && state?.isExpanded) {
        if (state.isShowingGeminiSettings) {
          void dispatchMaki('toggleGeminiSettings');
        } else if (state.isNotchChatMode) {
          void dispatchMaki('closeNotchChat');
        } else if (state.isMirrorOpen) {
          void dispatchMaki('closeMirror');
        } else if (isVoiceRecorderOpen) {
          setIsVoiceRecorderOpen(false);
        } else {
          void dispatchMaki('expand', { expanded: false });
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [state?.isExpanded, state?.isShowingGeminiSettings, state?.isNotchChatMode, state?.isMirrorOpen, isVoiceRecorderOpen]);

  const handleSelectTab = (tabId: IslandTab) => {
    if (isVoiceRecorderOpen) setIsVoiceRecorderOpen(false);
    if (state?.isMirrorOpen) void dispatchMaki('closeMirror');
    // 0ms optimistic switch for snappy, instant response matching macOS
    setActiveTab(tabId);
    void dispatchMaki('selectTab', { tab: tabId });
  };

  // Safe defaults ensure hooks are ALWAYS invoked unconditionally (React Rules of Hooks compliant)
  const target = state
    ? computeTargetIslandSize(state, activeTab, isVoiceRecorderOpen)
    : { width: 210, height: 32 };
  const earRadius = state?.isExpanded ? 10 : 8;
  const bottomRadius = state?.isExpanded ? 22 : compactHover ? 15 : 14;
  const targetInnerW = (state?.isExpanded ? target.width : target.width + (compactHover ? 16 : 0)) || 210;
  const targetTotalW = targetInnerW + earRadius * 2;
  const targetTotalH = (state?.isExpanded ? target.height : compactHover ? 35 : 32) || 32;

  // Smooth frame-by-frame spring animation (blooms downwards naturally from top to bottom!)
  const anim = useAnimatedNotch(targetTotalW, targetTotalH, bottomRadius, earRadius);
  const notchPath = buildNotchSvgPath(anim.w, anim.h, anim.bRad, anim.eRad);
  const animInnerW = Math.max(0, anim.w - anim.eRad * 2);

  const showMiniMaki = state?.showInCompactNotch && !state?.isOnDesktop;

  if (!state) {
    // Initial paint while IPC resolves snapshot - guarantees the notch NEVER disappears or blinks
    return (
      <div
        style={{
          width: ISLAND_CANVAS_WIDTH,
          height: ISLAND_CANVAS_HEIGHT,
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'flex-start',
          position: 'relative',
        }}
      >
        <div
          style={{
            width: anim.w,
            height: anim.h,
            position: 'relative',
            filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.30))',
          }}
        >
          <svg
            width={anim.w}
            height={anim.h}
            style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
          >
            <path d={notchPath} fill="#050507" />
            <path d={notchPath} fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth={0.6} />
          </svg>
        </div>
      </div>
    );
  }

  return (
    <div
      style={{
        width: ISLAND_CANVAS_WIDTH,
        height: ISLAND_CANVAS_HEIGHT,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'flex-start',
        position: 'relative',
      }}
    >
      <div
        className="notch-transition"
        onMouseEnter={() => {
          if (!state.isExpanded) {
            setCompactHover(true);
            window.maki.setCompactHover(true);
          }
        }}
        onMouseLeave={() => {
          setCompactHover(false);
          window.maki.setCompactHover(false);
        }}
        onDragOver={(e) => {
          e.preventDefault();
          window.maki.setDropHold(true);
        }}
        onDragLeave={() => {
          window.maki.setDropHold(false);
        }}
        onDrop={(e) => {
          e.preventDefault();
          window.maki.setDropHold(false);
          const paths = extractDroppedFilePaths(e);
          if (paths.length > 0) void dispatchMaki('dropFiles', { paths });
        }}
        style={{
          width: anim.w,
          height: anim.h,
          position: 'relative',
          filter: state.isExpanded
            ? 'drop-shadow(0 8px 18px rgba(0,0,0,0.45))'
            : 'drop-shadow(0 2px 6px rgba(0,0,0,0.28))',
        }}
      >
        {/* Hardware Black Notch Silhouette + Rim Highlight */}
        <svg
          width={anim.w}
          height={anim.h}
          style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        >
          <path d={notchPath} fill="#050507" />
          <path
            d={notchPath}
            fill="none"
            stroke={
              !state.isExpanded && compactHover
                ? 'rgba(255,255,255,0.26)'
                : 'rgba(255,255,255,0.10)'
            }
            strokeWidth={!state.isExpanded && compactHover ? 0.9 : 0.6}
          />
        </svg>

        {/* Inner Content Column */}
        <div
          style={{
            position: 'relative',
            marginLeft: anim.eRad,
            marginRight: anim.eRad,
            width: animInnerW,
            height: anim.h,
            overflow: 'hidden',
          }}
        >
          {!state.isExpanded ? (
            /* COMPACT NOTCH MODE */
            <div
              className="compact-island-in"
              onClick={() => {
                setCompactHover(false);
                window.maki.setCompactHover(false);
                void dispatchMaki('expand', { expanded: true });
              }}
              style={{
                position: 'absolute',
                top: 0,
                left: '50%',
                transform: 'translateX(-50%)',
                width: 210,
                height: 32,
                padding: '0 11px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                cursor: 'pointer',
                whiteSpace: 'nowrap',
              }}
            >
              {/* Left Indicator */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 5, minWidth: 0 }}>
                {state.timer.isTimeUpAlert ? (
                  <span style={{ fontSize: 10, fontWeight: 800, color: '#fb923c' }}>
                    🔔 WAKTU HABIS!
                  </span>
                ) : state.timer.totalSeconds > 0 ? (
                  <span
                    style={{
                      fontSize: 11,
                      fontWeight: 700,
                      color: '#fb923c',
                      fontVariantNumeric: 'tabular-nums',
                    }}
                  >
                    ⏳ {state.timer.formattedTime}
                  </span>
                ) : state.currentTrack.isPlaying ? (
                  <span
                    style={{
                      fontSize: 11,
                      fontWeight: 600,
                      maxWidth: 96,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    🎵 {state.currentTrack.title || 'Playing'}
                  </span>
                ) : state.droppedItems.length > 0 ? (
                  <span style={{ fontSize: 11, fontWeight: 600, color: '#60a5fa' }}>
                    📥 {state.droppedItems.length} file
                  </span>
                ) : (
                  <span style={{ fontSize: 11, fontWeight: 600 }}>
                    {state.system.isCharging ? (
                      <span style={{ color: '#4ade80', marginRight: 3 }}>⚡</span>
                    ) : (
                      <span style={{ marginRight: 3 }}>🔋</span>
                    )}
                    {state.system.batteryLevel}%
                  </span>
                )}
              </div>

              {/* Center Simulated Camera Lens Dot + Mic Mute Indicator */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                <div
                  style={{
                    width: 9,
                    height: 9,
                    borderRadius: 99,
                    border: '1px solid rgba(255,255,255,0.14)',
                    background: 'rgba(255,255,255,0.06)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <div
                    style={{
                      width: 2.5,
                      height: 2.5,
                      borderRadius: 99,
                      background: 'rgba(34,211,238,0.45)',
                    }}
                  />
                </div>
                {state.isMicMuted && (
                  <span style={{ fontSize: 9, color: '#ef4444', fontWeight: 800 }}>🎙️✕</span>
                )}
              </div>

              {/* Right Indicator + Mini 2D Maki */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                {showMiniMaki && (
                  <Capybara2DCanvas
                    width={24}
                    height={22}
                    role={
                      state.currentTrack.isPlaying
                        ? 'djMusic'
                        : state.timer.isRunning
                        ? 'senseiTimer'
                        : 'habitat'
                    }
                    action={state.currentAction}
                    eatingEmoji={state.eatingEmoji}
                    orangesOnHead={state.orangesOnHead}
                    isListeningMusic={state.currentTrack.isPlaying}
                    isFocusing={state.timer.isRunning}
                    isMouthOpenForDrop={state.isMouthOpenForDrop}
                    lookVector={state.lookVector}
                    lastSquishTime={state.lastSquishTime}
                    mascotModel={state.mascotModel}
                  />
                )}
                {state.currentTrack.isPlaying ? (
                  <AudioWaveform isPlaying={true} />
                ) : (
                  <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.62)', fontWeight: 500 }}>
                    {clock}
                  </span>
                )}
              </div>
            </div>
          ) : (
            /* EXPANDED NOTCH MODE */
            <div
              className="island-bloom-down"
              style={{
                position: 'absolute',
                top: 0,
                left: '50%',
                transform: 'translateX(-50%)',
                width: target.width,
                height: target.height,
                padding: '8px 16px 8px',
                display: 'flex',
                flexDirection: 'column',
                gap: 6,
                transformOrigin: 'top center',
              }}
            >
              {state.isShowingOnboarding ? (
                <OnboardingModal state={state} />
              ) : (
                <>
                  {/* Top Bar: Horizontal Scrollable Tabs + Quick Actions (macOS 1:1 Parity) */}
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 6,
                      width: '100%',
                      padding: '0 2px',
                    }}
                  >
                    {/* Horizontal Scrollable Tabs */}
                    <div
                      className="no-scrollbar"
                      style={{
                        display: 'flex',
                        gap: 5,
                        alignItems: 'center',
                        overflowX: 'auto',
                        flex: 1,
                        minWidth: 0,
                        paddingBottom: 2,
                      }}
                    >
                      {ALL_ISLAND_TABS.map((tab) => {
                        const isTabActive = activeTab === tab.id;
                        return (
                          <button
                            key={tab.id}
                            onClick={() => handleSelectTab(tab.id)}
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 3.5,
                              padding: '4.5px 9px',
                              borderRadius: 99,
                              fontSize: 10,
                              fontWeight: 600,
                              background: isTabActive ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.06)',
                              color: isTabActive ? '#ffffff' : 'rgba(255,255,255,0.58)',
                              whiteSpace: 'nowrap',
                              border: isTabActive ? '1px solid rgba(255,255,255,0.20)' : '1px solid transparent',
                              cursor: 'pointer',
                              transition: 'background 0.15s ease, color 0.15s ease',
                              flexShrink: 0,
                            }}
                            title={tab.label}
                          >
                            <span style={{ fontSize: 10 }}>{tab.icon}</span>
                            <span style={{ letterSpacing: -0.1 }}>{tab.label}</span>
                          </button>
                        );
                      })}
                    </div>

                    {/* Quick Action Buttons on Right (macOS 1:1 Parity) */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5, flexShrink: 0 }}>
                      {/* Update Badge (if available) */}
                      {state.updateAvailable && (
                        <button
                          onClick={() => {
                            if (state.updateAvailable?.isDownloading) return;
                            void dispatchMaki('applyUpdate');
                          }}
                          title={
                            state.updateAvailable.isDownloading
                              ? `Sedang mengunduh pembaruan (${state.updateAvailable.downloadPercent || 0}%)...`
                              : `Pembaruan v${state.updateAvailable.version} tersedia!`
                          }
                          style={{
                            padding: '3px 7px',
                            borderRadius: 99,
                            background: state.updateAvailable.isDownloading
                              ? 'rgba(59,130,246,0.35)'
                              : 'rgba(34,197,94,0.30)',
                            color: state.updateAvailable.isDownloading ? '#93c5fd' : '#4ade80',
                            fontSize: 8.8,
                            fontWeight: 700,
                            border: 'none',
                            cursor: state.updateAvailable.isDownloading ? 'default' : 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 3,
                          }}
                        >
                          <span>{state.updateAvailable.isDownloading ? '⏳' : '✨'}</span>
                          <span>
                            {state.updateAvailable.isDownloading
                              ? `${state.updateAvailable.downloadPercent || 0}%`
                              : 'Update'}
                          </span>
                        </button>
                      )}

                      {/* Quick Mirror / Camera Button */}
                      <button
                        onClick={() => {
                          setIsVoiceRecorderOpen(false);
                          void dispatchMaki('toggleMirror');
                        }}
                        title="Buka Cermin Kamera (Mirror Webcam)"
                        style={{
                          padding: '3.5px 7px',
                          borderRadius: 99,
                          background: state.isMirrorOpen
                            ? 'rgba(168,85,247,0.38)'
                            : 'rgba(168,85,247,0.18)',
                          color: state.isMirrorOpen ? '#ffffff' : 'rgba(216,180,254,0.9)',
                          fontSize: 9,
                          fontWeight: 700,
                          border: 'none',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 3,
                        }}
                      >
                        <span>🪞</span>
                        <span>Mirror</span>
                      </button>

                      {/* Quick Voice Recorder Button */}
                      <button
                        onClick={() => {
                          if (state.isMirrorOpen) void dispatchMaki('closeMirror');
                          setIsVoiceRecorderOpen((v) => !v);
                        }}
                        title="Rekam Memo Suara (Voice Recorder)"
                        style={{
                          padding: '3.5px 7px',
                          borderRadius: 99,
                          background: isVoiceRecorderOpen
                            ? 'rgba(239,68,68,0.38)'
                            : 'rgba(239,68,68,0.18)',
                          color: isVoiceRecorderOpen ? '#ffffff' : 'rgba(248,113,113,0.9)',
                          fontSize: 9,
                          fontWeight: 700,
                          border: 'none',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 3,
                        }}
                      >
                        <span>🎙️</span>
                        <span>Rekam</span>
                      </button>

                      {/* Help / Onboarding Guide Button */}
                      <button
                        onClick={() => void dispatchMaki('openOnboarding')}
                        title="Panduan Penggunaan & Setup API Key"
                        style={{
                          width: 20,
                          height: 20,
                          borderRadius: 99,
                          color: 'rgba(255,255,255,0.55)',
                          fontSize: 11,
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          padding: 0,
                        }}
                      >
                        ❓
                      </button>

                      {/* Global Mic Mute Button */}
                      <button
                        onClick={() => void dispatchMaki('toggleMicMute')}
                        title="Mute / Unmute Mikrofon Windows"
                        style={{
                          padding: state.isMicMuted ? '4px 7px' : '4px 5px',
                          borderRadius: 99,
                          background: state.isMicMuted
                            ? 'rgba(239,68,68,0.25)'
                            : 'rgba(255,255,255,0.08)',
                          color: state.isMicMuted ? '#ef4444' : 'rgba(255,255,255,0.55)',
                          fontSize: 9,
                          fontWeight: 700,
                          border: 'none',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 3,
                        }}
                      >
                        <span>{state.isMicMuted ? '🔇' : '🎙️'}</span>
                        {state.isMicMuted && <span>Muted</span>}
                      </button>

                      {/* Pin Button */}
                      <button
                        onClick={() => void dispatchMaki('togglePin')}
                        title={state.isPinned ? 'Lepas Pin (Auto-minimize aktif)' : 'Pin agar tetap terbuka'}
                        style={{
                          width: 22,
                          height: 22,
                          borderRadius: 99,
                          color: state.isPinned ? '#fb923c' : 'rgba(255,255,255,0.35)',
                          fontSize: 11,
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          padding: 0,
                        }}
                      >
                        📌
                      </button>

                      {/* Minimize Chevron */}
                      <button
                        onClick={() => void dispatchMaki('expand', { expanded: false })}
                        title="Tutup Detail (Esc)"
                        style={{
                          width: 22,
                          height: 22,
                          borderRadius: 99,
                          color: 'rgba(255,255,255,0.45)',
                          fontSize: 10,
                          fontWeight: 600,
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          padding: 0,
                        }}
                      >
                        ⌃
                      </button>
                    </div>
                  </div>

                  {/* Main Content + Contextual Maki Card */}
                  <div
                    style={{
                      flex: 1,
                      minHeight: 0,
                      display: 'flex',
                      alignItems: 'stretch',
                      gap: 10,
                      position: 'relative',
                    }}
                  >
                    {/* Camera Mirror Overlay (if open) */}
                    {state.isMirrorOpen && (
                      <CameraMirrorModal onClose={() => void dispatchMaki('closeMirror')} />
                    )}

                    {/* Voice Recorder Overlay (if open) */}
                    {isVoiceRecorderOpen && (
                      <VoiceRecorderPanel
                        onClose={() => setIsVoiceRecorderOpen(false)}
                        onSaved={() => setIsVoiceRecorderOpen(false)}
                      />
                    )}

                    {!state.isMirrorOpen && !isVoiceRecorderOpen && (
                      <>
                        <div style={{ flex: 1, minWidth: 0, minHeight: 0 }}>
                          {activeTab === 'maki-land' && <MakiLandTab state={state} />}
                          {activeTab === 'Capy' && <CapyHabitatTab state={state} />}
                          {activeTab === 'Notes' && <NotesTab state={state} />}
                          {activeTab === 'Launch' && <LauncherTab state={state} />}
                          {activeTab === 'Tray' && <TrayTab state={state} />}
                          {activeTab === 'System' && <SystemTab state={state} />}
                          {activeTab === 'Clipboard' && <ClipboardTab state={state} />}
                          {activeTab === 'Timer' && <TimerTab state={state} />}
                        </div>

                        {activeTab !== 'Capy' && (
                          <ContextualCapyCard tab={activeTab} state={state} />
                        )}

                        {/* Contextual Tip Bubble beside Maki */}
                        {activeTab !== 'Capy' && state.contextualTip && (
                          <div
                            style={{
                              position: 'absolute',
                              right: 96,
                              top: 8,
                              zIndex: 50,
                              pointerEvents: 'none',
                            }}
                          >
                            <CapySpeechBubble
                              text={state.contextualTip}
                              tail="right"
                              fontSize={9.6}
                              maxWidth={176}
                            />
                          </div>
                        )}
                      </>
                    )}
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
