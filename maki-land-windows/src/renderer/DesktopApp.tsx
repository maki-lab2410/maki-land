import React, { useEffect, useRef } from 'react';
import {
  CapyRole,
  DESKTOP_CHAT_HEIGHT,
  DESKTOP_CHAT_WIDTH,
  DESKTOP_NORMAL_HEIGHT,
  DESKTOP_NORMAL_WIDTH,
  roleFromTab,
} from '../shared/types';
import { dispatchMaki, extractDroppedFilePaths, useMakiState } from './bridge';
import { Capybara2DCanvas } from './components/Capybara2DCanvas';
import { CapySpeechBubble } from './components/CapySpeechBubble';
import { MakiChatBody } from './components/MakiChatViews';

export const DesktopApp: React.FC = () => {
  const state = useMakiState();
  const dragMovedRef = useRef(false);
  const draggingRef = useRef(false);
  const isCompanion =
    typeof window !== 'undefined' &&
    (new URLSearchParams(window.location.search).get('mascot') === 'moko' ||
      (window as unknown as Record<string, unknown>)['__MAKI_COMPANION__'] === 'moko');

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      if (!draggingRef.current) return;
      dragMovedRef.current = true;
      if (isCompanion) {
        window.maki.companionDragMove(e.screenX, e.screenY);
      } else {
        window.maki.desktopDragMove(e.screenX, e.screenY);
      }
    };
    const onUp = (e: MouseEvent) => {
      if (!draggingRef.current) return;
      draggingRef.current = false;
      if (isCompanion) {
        window.maki.companionDragEnd(e.screenX, e.screenY);
      } else {
        window.maki.desktopDragEnd(e.screenX, e.screenY);
      }
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && state?.isDesktopChatOpen && !isCompanion) {
        if (state.isShowingGeminiSettings) void dispatchMaki('toggleGeminiSettings');
        else void dispatchMaki('toggleDesktopChat');
      }
    };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
      window.removeEventListener('keydown', onKey);
    };
  }, [state?.isDesktopChatOpen, state?.isShowingGeminiSettings, isCompanion]);

  if (!state) return null;

  let activeRole: CapyRole = 'habitat';
  if (state.isOnsenMode) activeRole = 'habitat';
  else if (state.currentTrack.isPlaying) activeRole = 'djMusic';
  else if (state.timer.isRunning) activeRole = 'senseiTimer';
  else if (state.isExpanded && state.selectedTab !== 'Capy') {
    activeRole = roleFromTab(state.selectedTab);
  }

  const displayedBubble = isCompanion
    ? state.companionBubble
    : state.isMouthOpenForDrop
      ? state.isDesktopChatOpen
        ? 'lepas buat ditanyakan..'
        : 'sini kasih ke aku..'
      : state.desktopBubble;

  const isChat = !isCompanion && state.isDesktopChatOpen && !state.isReturningToNotch;
  const winW = isChat ? DESKTOP_CHAT_WIDTH : DESKTOP_NORMAL_WIDTH;
  const winH = isChat ? DESKTOP_CHAT_HEIGHT : DESKTOP_NORMAL_HEIGHT;
  const showDock = isCompanion
    ? true
    : (state.desktopPointerInside || isChat) &&
      !state.isDraggingOnDesktop &&
      !state.isReturningToNotch;

  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();
        if (!isCompanion) window.maki.setDropHold(true);
      }}
      onDragLeave={() => {
        if (!isCompanion) window.maki.setDropHold(false);
      }}
      onDrop={(e) => {
        e.preventDefault();
        if (!isCompanion) {
          window.maki.setDropHold(false);
          const paths = extractDroppedFilePaths(e);
          if (paths.length > 0) void dispatchMaki('dropFiles', { paths });
        }
      }}
      onContextMenu={(e) => {
        e.preventDefault();
        if (isCompanion) window.maki.showCompanionContextMenu();
        else window.maki.showDesktopContextMenu();
      }}
      style={{
        width: winW,
        height: winH,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'flex-end',
        gap: 2,
        paddingBottom: 2,
      }}
    >
      {/* Top Area: Either Floating Desktop AI Chat Card OR Snug Comic Speech Bubble */}
      {isChat ? (
        <div
          style={{
            width: 328,
            height: 228,
            background: 'rgba(255, 252, 247, 0.98)',
            backdropFilter: 'blur(16px)',
            border: '1.2px solid rgba(65, 38, 18, 0.22)',
            borderRadius: 18,
            padding: '9px 11px',
            boxShadow:
              '0 14px 38px rgba(50, 25, 10, 0.14), 0 3px 10px rgba(0, 0, 0, 0.05)',
            position: 'relative',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <MakiChatBody state={state} compactDesktop theme="light" />

          {/* Comic speech bubble tail pointing down to Maki */}
          <div
            style={{
              position: 'absolute',
              bottom: -6,
              left: '50%',
              transform: 'translateX(-50%) rotate(45deg)',
              width: 12,
              height: 12,
              background: 'rgba(255, 252, 247, 0.98)',
              borderRight: '1.2px solid rgba(65, 38, 18, 0.22)',
              borderBottom: '1.2px solid rgba(65, 38, 18, 0.22)',
              zIndex: 3,
            }}
          />
        </div>
      ) : (
        <div
          style={{
            width: 248,
            height: 46,
            display: 'flex',
            alignItems: 'flex-end',
            justifyContent: 'center',
            pointerEvents: 'none',
          }}
        >
          {displayedBubble && (
            <CapySpeechBubble text={displayedBubble} tail="bottom" fontSize={10.4} maxWidth={190} />
          )}
        </div>
      )}

      {/* Interactive 2D Stage (Maki or Companion Moko) */}
      <div
        onMouseDown={(e) => {
          if (e.button !== 0) return;
          dragMovedRef.current = false;
          draggingRef.current = true;
          if (isCompanion) {
            window.maki.companionDragStart(e.screenX, e.screenY);
          } else {
            window.maki.desktopDragStart(e.screenX, e.screenY);
          }
        }}
        onClick={(e) => {
          if (dragMovedRef.current) return;
          if (isCompanion) {
            void dispatchMaki('companionPet');
          } else {
            if (e.detail >= 2) {
              void dispatchMaki('randomTrick');
            } else {
              void dispatchMaki('pet', { tab: 'Capy', fromDesktop: true });
            }
          }
        }}
        onWheel={(e) => {
          if (!isCompanion && Math.hypot(e.deltaX, e.deltaY) > 4) {
            void dispatchMaki('strokeFur');
          }
        }}
        style={{
          position: 'relative',
          width: 122,
          height: 114,
          cursor: state.isDraggingOnDesktop ? 'grabbing' : 'grab',
          transform: isCompanion ? 'none' : `scale(${1 - state.notchClimbProgress * 0.72})`,
          transformOrigin: 'top center',
        }}
      >
        <Capybara2DCanvas
          width={122}
          height={114}
          role={isCompanion ? 'habitat' : activeRole}
          action={isCompanion ? state.companionAction : state.currentAction}
          eatingEmoji={state.eatingEmoji}
          orangesOnHead={isCompanion ? state.companionOranges : state.orangesOnHead}
          isOnsen={isCompanion ? state.companionIsOnsen : (state.isOnsenMode && !isChat)}
          isListeningMusic={!isCompanion && state.currentTrack.isPlaying}
          isFocusing={!isCompanion && state.timer.isRunning}
          isDangling={!isCompanion && state.isDraggingOnDesktop}
          isMouthOpenForDrop={!isCompanion && state.isMouthOpenForDrop}
          lookVector={state.lookVector}
          lastSquishTime={state.lastSquishTime}
          facingRight={isCompanion ? state.companionFacingRight : state.facingRight}
          mascotModel={isCompanion ? 'plushie' : state.mascotModel}
          nameBadge={isCompanion ? 'moko' : 'maki'}
        />

        {!isCompanion && state.currentTrack.isPlaying && !state.isDraggingOnDesktop && !state.isReturningToNotch && (
          <div
            style={{
              position: 'absolute',
              left: 2,
              top: 14,
              padding: '1.5px 6px',
              borderRadius: 99,
              background: 'rgba(255, 251, 242, 0.95)',
              border: '0.8px solid rgba(59, 33, 15, 0.24)',
              color: '#242429',
              fontSize: 9.5,
              fontWeight: 700,
              pointerEvents: 'none',
            }}
          >
            ♪ ♫
          </div>
        )}
      </div>

      {/* Warm Cream Glass Quick-Play Pill Dock */}
      <div
        style={{
          height: 27,
          padding: '3px 7px',
          borderRadius: 99,
          background: 'rgba(255, 251, 242, 0.96)',
          border: '1px solid rgba(59, 33, 15, 0.25)',
          boxShadow: '0 6px 18px rgba(50, 25, 10, 0.12), 0 2px 6px rgba(0, 0, 0, 0.04)',
          display: 'flex',
          alignItems: 'center',
          gap: 3.5,
          opacity: showDock ? 1 : 0,
          pointerEvents: showDock ? 'auto' : 'none',
          transition: 'opacity 0.16s ease',
        }}
      >
        {isCompanion
          ? [
              {
                icon: '💬',
                active: false,
                title: 'Ajak Ngobrol Maki',
                fn: () => void dispatchMaki('companionBanter'),
              },
              {
                icon: '🍊',
                active: false,
                title: 'Lempar Jeruk ke Maki',
                fn: () => void dispatchMaki('companionOrangeToss'),
              },
              {
                icon: '♨️',
                active: state.companionIsOnsen,
                title: state.companionIsOnsen ? 'Selesai Berendam' : 'Berendam Onsen Bersama',
                fn: () => void dispatchMaki('companionToggleOnsen'),
              },
              {
                icon: '🚶',
                active: false,
                title: 'Jalan-jalan Santai',
                fn: () => void dispatchMaki('companionToggleRoam'),
              },
              {
                icon: '🐾',
                active: false,
                title: 'Tos / High-Five dengan Maki!',
                fn: () => void dispatchMaki('companionHighFive'),
              },
              {
                icon: '🏠',
                active: false,
                title: 'Jalan Pulang ke Notch bersama Maki',
                fn: () => void dispatchMaki('returnToNotch'),
              },
            ].map((btn, i) => (
              <button
                key={i}
                title={btn.title}
                onClick={btn.fn}
                style={{
                  width: 24,
                  height: 20,
                  borderRadius: 99,
                  fontSize: 11,
                  background: btn.active ? 'rgba(251, 146, 60, 0.38)' : 'rgba(0, 0, 0, 0.06)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                {btn.icon}
              </button>
            ))
          : [
              {
                icon: '💬',
                active: isChat,
                title: 'Tanya Jawab dengan Maki (Gemini AI)',
                fn: () => void dispatchMaki('toggleDesktopChat'),
              },
              {
                icon: '📸',
                active: false,
                title: 'Ambil Screenshot Clipboard / Terakhir ke Tray',
                fn: () => void dispatchMaki('grabScreenshot'),
              },
              {
                icon: '🎪',
                active: false,
                title: 'Atraksi Acak',
                fn: () => void dispatchMaki('randomTrick'),
              },
              {
                icon: state.isChasingCursor ? '⏹️' : '🐾',
                active: state.isChasingCursor,
                title: 'Main Kejar Kursor',
                fn: () => void dispatchMaki('toggleChaseCursor'),
              },
              {
                icon: '🍊',
                active: false,
                title: 'Kasih Jeruk',
                fn: () => void dispatchMaki('feed', { food: 'Jeruk' }),
              },
              {
                icon: '♨️',
                active: state.isOnsenMode,
                title: state.isOnsenMode ? 'Selesai Berendam Onsen' : 'Berendam Onsen Air Hangat',
                fn: () => void dispatchMaki('toggleOnsen'),
              },
              {
                icon: '🧹',
                active: state.cacheCleaner?.isCleaning,
                title: 'Sapu Bersih Cache Aman ke Recycle Bin (Maki Clean)',
                fn: () => void dispatchMaki('cleanCache'),
              },
              {
                icon: state.desktopRoamEnabled ? '🚶' : '📌',
                active: !state.desktopRoamEnabled,
                title: state.desktopRoamEnabled
                  ? 'Sedang Bebas Jalan (Klik untuk Kunci Posisi)'
                  : 'Posisi Dikunci (Klik agar Bebas Jalan)',
                fn: () => void dispatchMaki('toggleDesktopRoam'),
              },
              {
                icon: '🏠',
                active: false,
                title: 'Jalan Pulang ke Notch',
                fn: () => void dispatchMaki('returnToNotch'),
              },
            ].map((btn, i) => (
              <button
                key={i}
                title={btn.title}
                onClick={btn.fn}
                style={{
                  width: 22,
                  height: 20,
                  borderRadius: 99,
                  fontSize: 11,
                  background: btn.active ? 'rgba(251, 146, 60, 0.38)' : 'rgba(0, 0, 0, 0.06)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                {btn.icon}
              </button>
            ))}
      </div>
    </div>
  );
};
