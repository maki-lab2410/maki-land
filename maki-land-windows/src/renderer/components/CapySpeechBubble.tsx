import React, { useState } from 'react';
import {
  IslandTab,
  roleBadgeLabel,
  roleFromTab,
  SharedAppState,
} from '../../shared/types';
import { dispatchMaki, extractDroppedFilePaths } from '../bridge';
import { Capybara2DCanvas } from './Capybara2DCanvas';

export const CapySpeechBubble: React.FC<{
  text: string;
  tail?: 'bottom' | 'right';
  fontSize?: number;
  maxWidth?: number;
}> = ({ text, tail = 'bottom', fontSize = 10, maxWidth = 190 }) => {
  return (
    <div
      style={{
        position: 'relative',
        display: 'inline-block',
        maxWidth,
        padding: '4.5px 10px',
        borderRadius: 12,
        background: 'rgba(255, 251, 242, 0.96)',
        color: '#2b1b0e',
        fontSize,
        fontWeight: 600,
        lineHeight: 1.32,
        border: '1px solid rgba(59, 33, 15, 0.28)',
        boxShadow: '0 6px 18px rgba(50, 25, 10, 0.12), 0 2px 6px rgba(0, 0, 0, 0.04)',
        pointerEvents: 'none',
        textAlign: 'center',
      }}
    >
      <span>{text}</span>
      {tail === 'bottom' ? (
        <span
          style={{
            position: 'absolute',
            left: '50%',
            bottom: -5,
            transform: 'translateX(-50%) rotate(45deg)',
            width: 8,
            height: 8,
            background: 'rgba(255, 251, 242, 0.96)',
            borderRight: '1px solid rgba(59, 33, 15, 0.28)',
            borderBottom: '1px solid rgba(59, 33, 15, 0.28)',
          }}
        />
      ) : (
        <span
          style={{
            position: 'absolute',
            right: -4.5,
            top: '50%',
            transform: 'translateY(-50%) rotate(-45deg)',
            width: 8,
            height: 8,
            background: 'rgba(255, 251, 242, 0.96)',
            borderRight: '1px solid rgba(59, 33, 15, 0.28)',
            borderBottom: '1px solid rgba(59, 33, 15, 0.28)',
          }}
        />
      )}
    </div>
  );
};

export const ContextualCapyCard: React.FC<{
  tab: IslandTab;
  state: SharedAppState;
}> = ({ tab, state }) => {
  const [hovering, setHovering] = useState(false);
  const [dropTarget, setDropTarget] = useState(false);
  const [showHeart, setShowHeart] = useState(false);

  const role = roleFromTab(tab);
  const badge = roleBadgeLabel(role);

  const accentMap: Record<string, string> = {
    djMusic: '#22c55e',
    habitat: '#fb923c',
    scholarNotes: '#facc15',
    pilotLauncher: '#22d3ee',
    builderTray: '#fb923c',
    mechanicSystem: '#3b82f6',
    detectiveClipboard: '#a855f7',
    senseiTimer: '#fb923c',
  };
  const accent = accentMap[role] || '#fb923c';

  const triggerHeart = () => {
    setShowHeart(true);
    setTimeout(() => setShowHeart(false), 850);
  };

  return (
    <div
      onMouseEnter={() => setHovering(true)}
      onMouseLeave={() => setHovering(false)}
      onDragOver={(e) => {
        e.preventDefault();
        setDropTarget(true);
        window.maki.setDropHold(true);
      }}
      onDragLeave={() => {
        setDropTarget(false);
        window.maki.setDropHold(false);
      }}
      onDrop={(e) => {
        e.preventDefault();
        setDropTarget(false);
        window.maki.setDropHold(false);
        const paths = extractDroppedFilePaths(e);
        if (paths.length > 0) void dispatchMaki('dropFiles', { paths });
      }}
      style={{
        width: 88,
        flexShrink: 0,
        padding: '4px 5px',
        borderRadius: 12,
        background: dropTarget
          ? 'rgba(251, 146, 60, 0.22)'
          : hovering
          ? 'rgba(255, 255, 255, 0.08)'
          : 'rgba(255, 255, 255, 0.045)',
        border: `1px solid ${dropTarget ? '#fb923c' : hovering ? `${accent}77` : `${accent}2b`}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 2,
      }}
      title="Klik: Elus Maki • Drop File: Masuk Tray"
    >
      <div
        style={{
          width: '100%',
          textAlign: 'center',
          fontSize: 8.5,
          fontWeight: 700,
          padding: '2px 4px',
          borderRadius: 99,
          background: `${accent}44`,
          border: `0.6px solid ${accent}88`,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {badge}
      </div>

      <div style={{ position: 'relative', width: 76, height: 60, cursor: 'pointer' }}>
        <Capybara2DCanvas
          width={76}
          height={60}
          role={role}
          action={state.currentAction}
          eatingEmoji={state.eatingEmoji}
          orangesOnHead={state.orangesOnHead}
          isOnsen={false}
          isListeningMusic={state.currentTrack.isPlaying}
          isFocusing={state.timer.isRunning}
          isMouthOpenForDrop={dropTarget || state.isMouthOpenForDrop}
          lookVector={state.lookVector}
          lastSquishTime={state.lastSquishTime}
          mascotModel={state.mascotModel}
          onClick={() => {
            void dispatchMaki('pet', { tab });
            triggerHeart();
          }}
        />
        {tab === 'System' && state.system.cpuPercent >= 60 && (
          <span style={{ position: 'absolute', right: 4, top: 8, fontSize: 9 }}>💦</span>
        )}
        {tab === 'maki-land' && state.currentTrack.isPlaying && (
          <span style={{ position: 'absolute', left: 4, top: 8, fontSize: 10, color: '#4ade80', fontWeight: 700 }}>
            ♪
          </span>
        )}
        {showHeart && (
          <div
            className="heart-burst"
            style={{ position: 'absolute', top: 4, left: '34%', fontSize: 10 }}
          >
            ❤️✨
          </div>
        )}
      </div>

      <div style={{ display: 'flex', gap: 3 }}>
        <button
          title="Tanya Maki (Gemini AI)"
          onClick={() => void dispatchMaki('openNotchChat')}
          style={{
            width: 18,
            height: 16,
            borderRadius: 99,
            background: 'rgba(251, 146, 60, 0.24)',
            fontSize: 8.5,
          }}
        >
          💬
        </button>
        <button
          title="Elus Maki"
          onClick={() => {
            void dispatchMaki('pet', { tab });
            triggerHeart();
          }}
          style={{
            width: 18,
            height: 16,
            borderRadius: 99,
            background: 'rgba(255, 255, 255, 0.09)',
            fontSize: 8.5,
          }}
        >
          👋
        </button>
        <button
          title="Kasih Jeruk"
          onClick={() => {
            void dispatchMaki('feed', { food: 'Jeruk' });
            triggerHeart();
          }}
          style={{
            width: 18,
            height: 16,
            borderRadius: 99,
            background: 'rgba(251, 146, 60, 0.18)',
            fontSize: 8.5,
          }}
        >
          🍊
        </button>
        <button
          title={state.isOnDesktop ? 'Panggil Maki kembali ke Notch' : 'Lepas Maki ke Desktop'}
          onClick={() => void dispatchMaki('toggleDesktop')}
          style={{
            width: 18,
            height: 16,
            borderRadius: 99,
            background: state.isOnDesktop
              ? 'rgba(34, 197, 94, 0.22)'
              : 'rgba(34, 211, 238, 0.20)',
            fontSize: 8.5,
          }}
        >
          {state.isOnDesktop ? '🏠' : '🖥️'}
        </button>
      </div>
    </div>
  );
};
