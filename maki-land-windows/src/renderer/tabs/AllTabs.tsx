import React, { useEffect, useState } from 'react';
import {
  CAPY_FOODS,
  DroppedItem,
  SharedAppState,
  TodoItem,
} from '../../shared/types';
import { dispatchMaki, extractDroppedFilePaths } from '../bridge';
import { Capybara2DCanvas } from '../components/Capybara2DCanvas';
import { CapySpeechBubble } from '../components/CapySpeechBubble';
import { MakiChatBody } from '../components/MakiChatViews';

export const AudioWaveform: React.FC<{ isPlaying: boolean; color?: string; bars?: number }> = ({
  isPlaying,
  color = '#4ade80',
  bars = 4,
}) => (
  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2, height: 12 }}>
    {Array.from({ length: bars }).map((_, i) => (
      <span
        key={i}
        style={{
          width: 2.3,
          height: isPlaying ? 11 : 3,
          borderRadius: 99,
          background: color,
          animation: isPlaying ? `waveBounce ${0.55 + i * 0.14}s ease-in-out infinite` : 'none',
          transformOrigin: 'center',
        }}
      />
    ))}
  </div>
);

// 1. ✨ maki-land Tab (Media Now Playing + Calendar Glance)
export const MakiLandTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [dayOffset, setDayOffset] = useState(0);
  const [addingEvent, setAddingEvent] = useState(false);
  const [evTitle, setEvTitle] = useState('');
  const [evTime, setEvTime] = useState('09:00');
  const [icsDraft, setIcsDraft] = useState(state.googleICSUrl);

  const targetDate = new Date();
  targetDate.setDate(targetDate.getDate() + dayOffset);
  const targetISO = targetDate.toISOString().slice(0, 10);
  const dateLabel = targetDate.toLocaleDateString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });

  const dayEvents = state.calendarEvents.filter((e) => e.dateISO === targetISO);
  const track = state.currentTrack;

  return (
    <div style={{ display: 'flex', alignItems: 'stretch', gap: 10, width: '100%', height: '100%' }}>
      {/* Left: Media Now Playing */}
      <div
        style={{
          width: 218,
          flexShrink: 0,
          background: 'rgba(255,255,255,0.045)',
          border: '1px solid rgba(255,255,255,0.08)',
          borderRadius: 13,
          padding: '8px 10px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 9,
              background: track.isPlaying
                ? 'linear-gradient(135deg, rgba(34,197,94,0.35), rgba(16,185,129,0.15))'
                : 'rgba(255,255,255,0.08)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 16,
              flexShrink: 0,
            }}
          >
            {track.isPlaying ? '🎵' : '🎧'}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div
              style={{
                fontSize: 11,
                fontWeight: 700,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {track.title || 'Belum ada musik'}
            </div>
            <div
              style={{
                fontSize: 9.2,
                color: 'rgba(255,255,255,0.58)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {track.artist || (track.appName ? track.appName : 'Spotify / Browser / Media')}
            </div>
          </div>
          <AudioWaveform isPlaying={track.isPlaying} />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, marginTop: 6 }}>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('mediaControl', { cmd: 'prev' })}
            title="Lagu Sebelumnya"
          >
            ⏮
          </button>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('mediaControl', { cmd: 'playPause' })}
            style={{
              padding: '4px 14px',
              background: track.isPlaying ? 'rgba(34,197,94,0.28)' : 'rgba(255,255,255,0.14)',
              color: track.isPlaying ? '#4ade80' : '#fff',
              fontWeight: 700,
            }}
          >
            {track.isPlaying ? '⏸ Pause' : '▶ Play'}
          </button>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('mediaControl', { cmd: 'next' })}
            title="Lagu Berikutnya"
          >
            ⏭
          </button>
        </div>
      </div>

      {/* Right: Calendar Glance */}
      <div
        style={{
          flex: 1,
          minWidth: 0,
          background: 'rgba(255,255,255,0.04)',
          border: '1px solid rgba(255,255,255,0.08)',
          borderRadius: 13,
          padding: '7px 10px',
          display: 'flex',
          flexDirection: 'column',
          gap: 5,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ fontSize: 10, fontWeight: 700, color: '#fb923c' }}>📅 {dateLabel}</span>
          <button className="pill-btn" style={{ padding: '1px 5px' }} onClick={() => setDayOffset((d) => d - 1)}>
            ‹
          </button>
          {dayOffset !== 0 && (
            <button className="pill-btn" style={{ padding: '1px 5px' }} onClick={() => setDayOffset(0)}>
              Hari Ini
            </button>
          )}
          <button className="pill-btn" style={{ padding: '1px 5px' }} onClick={() => setDayOffset((d) => d + 1)}>
            ›
          </button>
          <div style={{ flex: 1 }} />
          <button
            className="pill-btn"
            style={{ padding: '2px 6px' }}
            onClick={() => setAddingEvent((v) => !v)}
            title="Tambah Jadwal Lokal"
          >
            + Jadwal
          </button>
          <button
            className="pill-btn"
            style={{
              padding: '2px 6px',
              background: state.isShowingCalendarSettings ? 'rgba(59,130,246,0.3)' : undefined,
            }}
            onClick={() => void dispatchMaki('toggleCalendarSettings')}
            title="Sinkron Google / Outlook Calendar (.ics)"
          >
            ⚙️ .ics
          </button>
        </div>

        {state.isShowingCalendarSettings ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
            <div style={{ fontSize: 8.8, color: 'rgba(255,255,255,0.65)' }}>
              Tempel Secret Address iCal (<code>.ics</code>) dari Google Calendar / Outlook:
            </div>
            <div style={{ display: 'flex', gap: 5 }}>
              <input
                value={icsDraft}
                onChange={(e) => setIcsDraft(e.target.value)}
                placeholder="https://calendar.google.com/calendar/ical/.../basic.ics"
                style={{
                  flex: 1,
                  background: 'rgba(0,0,0,0.45)',
                  border: '1px solid rgba(255,255,255,0.16)',
                  borderRadius: 7,
                  padding: '4px 7px',
                  color: '#fff',
                  fontSize: 9.2,
                }}
              />
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('syncGoogleICS', { url: icsDraft })}
                style={{ background: 'rgba(59,130,246,0.3)', color: '#60a5fa' }}
              >
                {state.isSyncingICS ? '...' : 'Sinkron'}
              </button>
            </div>
            {state.calendarError && (
              <div style={{ fontSize: 8.5, color: '#fca5a5' }}>{state.calendarError}</div>
            )}
          </div>
        ) : addingEvent ? (
          <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
            <input
              value={evTime}
              onChange={(e) => setEvTime(e.target.value)}
              style={{
                width: 48,
                background: 'rgba(0,0,0,0.4)',
                border: '1px solid rgba(255,255,255,0.16)',
                borderRadius: 6,
                padding: '3px 5px',
                color: '#fff',
                fontSize: 9.2,
              }}
            />
            <input
              value={evTitle}
              onChange={(e) => setEvTitle(e.target.value)}
              placeholder="Nama agenda..."
              onKeyDown={(e) => {
                if (e.key === 'Enter' && evTitle.trim()) {
                  void dispatchMaki('addCalendarEvent', {
                    title: evTitle,
                    dateISO: targetISO,
                    timeLabel: evTime,
                  });
                  setEvTitle('');
                  setAddingEvent(false);
                }
              }}
              style={{
                flex: 1,
                background: 'rgba(0,0,0,0.4)',
                border: '1px solid rgba(255,255,255,0.16)',
                borderRadius: 6,
                padding: '3px 6px',
                color: '#fff',
                fontSize: 9.2,
              }}
            />
            <button
              className="pill-btn"
              onClick={() => {
                if (evTitle.trim()) {
                  void dispatchMaki('addCalendarEvent', {
                    title: evTitle,
                    dateISO: targetISO,
                    timeLabel: evTime,
                  });
                  setEvTitle('');
                  setAddingEvent(false);
                }
              }}
              style={{ background: 'rgba(34,197,94,0.28)', color: '#4ade80' }}
            >
              Simpan
            </button>
          </div>
        ) : (
          <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 4 }}>
            {dayEvents.length === 0 ? (
              <div style={{ fontSize: 9.5, color: 'rgba(255,255,255,0.48)', marginTop: 8 }}>
                Kosong — santai hari ini ✨
              </div>
            ) : (
              dayEvents.slice(0, 4).map((ev) => (
                <div
                  key={ev.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                    fontSize: 9.5,
                    background: 'rgba(255,255,255,0.05)',
                    padding: '3px 7px',
                    borderRadius: 7,
                  }}
                >
                  <span
                    style={{
                      width: 6,
                      height: 6,
                      borderRadius: 99,
                      background: ev.colorHex,
                      flexShrink: 0,
                    }}
                  />
                  <span style={{ color: 'rgba(255,255,255,0.65)', fontSize: 8.8 }}>{ev.timeLabel}</span>
                  <span
                    style={{
                      flex: 1,
                      fontWeight: 600,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {ev.title}
                  </span>
                  {ev.source === 'Local' && (
                    <button
                      onClick={() => void dispatchMaki('deleteCalendarEvent', { id: ev.id })}
                      style={{ fontSize: 9, color: 'rgba(255,255,255,0.4)' }}
                    >
                      ✕
                    </button>
                  )}
                </div>
              ))
            )}
          </div>
        )}
      </div>
    </div>
  );
};

// 2. 🐾 Capy Habitat Tab (+ Notch Gemini AI Chat)
export const CapyHabitatTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [dropTarget, setDropTarget] = useState(false);
  const [heart, setHeart] = useState(false);

  const triggerHeart = () => {
    setHeart(true);
    setTimeout(() => setHeart(false), 850);
  };

  const hintText = dropTarget
    ? state.isNotchChatMode
      ? 'lepas gambar buat ditanyakan..'
      : 'sini kasih filenya..'
    : state.isThinking
    ? 'bentar lagi mikir..'
    : state.isNotchChatMode
    ? 'drop gambar ke aku buat tanya isi gambarnya'
    : state.isReturningToNotch
    ? 'lagi jalan balik ke atas..'
    : state.isOnDesktop
    ? 'lagi main di desktop • klik panggil'
    : 'klik elus • lepas ke desktop • kasih screenshot';

  return (
    <div style={{ display: 'flex', gap: 12, width: '100%', height: '100%', padding: '3px 0' }}>
      {/* Left Interactive Stage */}
      <div
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
          width: state.isNotchChatMode ? 146 : 224,
          flexShrink: 0,
          borderRadius: 14,
          background: dropTarget
            ? 'linear-gradient(180deg, rgba(251,146,60,0.28), rgba(0,0,0,0.5))'
            : state.isOnsenMode
            ? 'linear-gradient(180deg, rgba(34,211,238,0.20), rgba(251,146,60,0.08), rgba(0,0,0,0.5))'
            : 'linear-gradient(180deg, rgba(34,197,94,0.18), rgba(16,185,129,0.06), rgba(0,0,0,0.5))',
          border: `1px solid ${dropTarget ? '#fb923c' : 'rgba(255,255,255,0.12)'}`,
          position: 'relative',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '6px 6px 4px',
        }}
      >
        <div style={{ zIndex: 10, minHeight: 24, display: 'flex', alignItems: 'center' }}>
          {state.speechBubble ? (
            <CapySpeechBubble
              text={state.speechBubble}
              tail="bottom"
              fontSize={state.isNotchChatMode ? 8.8 : 9.6}
              maxWidth={state.isNotchChatMode ? 132 : 196}
            />
          ) : (
            <span style={{ fontSize: 8.5, color: 'rgba(255,255,255,0.68)', textAlign: 'center' }}>
              {hintText}
            </span>
          )}
        </div>

        <div
          style={{
            position: 'relative',
            transform: `translateX(${state.isNotchChatMode ? 0 : state.posX * 0.45}px)`,
            transition: 'transform 0.55s cubic-bezier(0.22, 1, 0.36, 1)',
            cursor: 'pointer',
          }}
          onWheel={(e) => {
            if (Math.hypot(e.deltaX, e.deltaY) > 4) void dispatchMaki('strokeFur');
          }}
        >
          <Capybara2DCanvas
            width={state.isNotchChatMode ? 96 : 108}
            height={state.isNotchChatMode ? 84 : 92}
            role="habitat"
            action={state.currentAction}
            eatingEmoji={state.eatingEmoji}
            orangesOnHead={state.orangesOnHead}
            isOnsen={state.isOnsenMode && !state.isNotchChatMode}
            isListeningMusic={state.currentTrack.isPlaying}
            isFocusing={state.timer.isRunning}
            isMouthOpenForDrop={dropTarget || state.isMouthOpenForDrop}
            lookVector={state.lookVector}
            lastSquishTime={state.lastSquishTime}
            facingRight={state.isNotchChatMode ? true : state.facingRight}
            mascotModel={state.mascotModel}
            onClick={() => {
              void dispatchMaki('pet', { tab: 'Capy' });
              triggerHeart();
            }}
          />
          {state.currentAction === 'sleeping' && (
            <span style={{ position: 'absolute', right: 2, top: 8, fontSize: 10, color: '#22d3ee', fontWeight: 700 }}>
              zZz
            </span>
          )}
          {state.currentTrack.isPlaying && (
            <span style={{ position: 'absolute', left: 2, top: 10, fontSize: 10, color: '#4ade80', fontWeight: 700 }}>
              ♪ ♫
            </span>
          )}
          {heart && (
            <div className="heart-burst" style={{ position: 'absolute', top: 4, left: '38%', fontSize: 12 }}>
              ❤️✨
            </div>
          )}
        </div>
      </div>

      {/* Right Column: Gemini AI Chat OR Care & Desktop Controls */}
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        {state.isNotchChatMode ? (
          <MakiChatBody state={state} />
        ) : (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: 11.5, fontWeight: 700 }}>🐾 Maki Capybara</span>
              <span
                style={{
                  fontSize: 9.5,
                  fontWeight: 800,
                  padding: '2px 6px',
                  borderRadius: 99,
                  background: 'rgba(251, 146, 60, 0.25)',
                  color: '#fb923c',
                }}
              >
                Lv.{state.level}
              </span>
              <div style={{ flex: 1 }} />
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('openNotchChat')}
                style={{
                  background: 'rgba(251, 146, 60, 0.26)',
                  color: '#fb923c',
                  borderColor: 'rgba(251, 146, 60, 0.48)',
                }}
              >
                ✨ 💬 Tanya AI
              </button>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('toggleShowInCompact')}
                style={{
                  background: state.showInCompactNotch ? 'rgba(34,197,94,0.22)' : undefined,
                  color: state.showInCompactNotch ? '#4ade80' : 'rgba(255,255,255,0.55)',
                }}
              >
                {state.showInCompactNotch ? '✓ Di Notch' : '○ Di Notch'}
              </button>
            </div>

            {/* Stat Bars */}
            <div style={{ display: 'flex', gap: 10 }}>
              {[
                { label: `❤️ Mood ${state.mood}%`, val: state.mood, color: '#f472b6' },
                { label: `🍃 Kenyang ${state.fullness}%`, val: state.fullness, color: '#fb923c' },
              ].map((b) => (
                <div key={b.label} style={{ flex: 1 }}>
                  <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.78)', marginBottom: 3, fontWeight: 600 }}>
                    {b.label}
                  </div>
                  <div style={{ height: 5, borderRadius: 99, background: 'rgba(255,255,255,0.1)', overflow: 'hidden' }}>
                    <div
                      style={{
                        width: `${Math.max(0, Math.min(100, b.val))}%`,
                        height: '100%',
                        background: b.color,
                        borderRadius: 99,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>

            {/* Action Chips Row 1 */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('openNotchChat')}
                style={{ background: 'rgba(251,146,60,0.24)', color: '#fb923c' }}
              >
                💬 Ngobrol
              </button>
              <button className="pill-btn" onClick={() => void dispatchMaki('randomTrick')}>
                🎪 Atraksi
              </button>
              <button
                className="pill-btn"
                onClick={() => {
                  void dispatchMaki('pet', { tab: 'Capy' });
                  triggerHeart();
                }}
              >
                👋 Elus
              </button>
              {CAPY_FOODS.map((f) => (
                <button
                  key={f.id}
                  className="pill-btn"
                  onClick={() => {
                    void dispatchMaki('feed', { food: f.id });
                    triggerHeart();
                  }}
                >
                  {f.emoji} {f.id}
                </button>
              ))}
            </div>

            {/* Action Chips Row 2 */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('cycleOranges')}
                style={{
                  background: state.orangesOnHead > 0 ? 'rgba(250,204,21,0.22)' : undefined,
                  color: state.orangesOnHead > 0 ? '#facc15' : undefined,
                }}
              >
                🍊 Jeruk ({state.orangesOnHead}/3)
              </button>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('toggleOnsen')}
                style={{
                  background: state.isOnsenMode ? 'rgba(34,211,238,0.24)' : undefined,
                  color: state.isOnsenMode ? '#22d3ee' : undefined,
                }}
              >
                {state.isOnsenMode ? '♨️ Selesai' : '♨️ Onsen'}
              </button>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('toggleDesktop')}
                style={{
                  background: state.isOnDesktop ? 'rgba(34,197,94,0.24)' : undefined,
                  color: state.isOnDesktop ? '#4ade80' : undefined,
                }}
              >
                {state.isOnDesktop ? '🏠 Panggil ke Notch' : '🖥️ Lepas ke Desktop'}
              </button>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('toggleMascotModel')}
                style={{
                  background: state.mascotModel === 'plushie' ? 'rgba(34,211,238,0.24)' : undefined,
                  color: state.mascotModel === 'plushie' ? '#22d3ee' : undefined,
                }}
              >
                {state.mascotModel === 'plushie' ? '🧸 Boneka' : '🐾 Klasik'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

// 3. 📝 Notes & To-Do Tab
export const NotesTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [todoInput, setTodoInput] = useState('');
  const [isTodoMaximized, setIsTodoMaximized] = useState(false);
  const [viewingTodo, setViewingTodo] = useState<TodoItem | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.altKey && e.key >= '1' && e.key <= '9') {
        e.preventDefault();
        void dispatchMaki('toggleTodoIndex', { index: Number(e.key) - 1 });
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', display: 'flex' }}>
      <div style={{ display: 'flex', gap: 10, width: '100%', height: '100%' }}>
        {/* Scratchpad (hidden when To-Do is maximized for full reading space!) */}
        {!isTodoMaximized && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: '#facc15' }}>📝 Scratchpad</span>
              <span style={{ fontSize: 8.5, color: 'rgba(255,255,255,0.45)' }}>Ctrl+Enter → To-Do</span>
            </div>
            <textarea
              value={state.scratchpadText}
              onChange={(e) => void dispatchMaki('setScratchpad', { text: e.target.value })}
              onKeyDown={(e) => {
                if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                  e.preventDefault();
                  const target = e.currentTarget;
                  const pos = target.selectionStart || 0;
                  const lines = state.scratchpadText.split(/\r?\n/);
                  let acc = 0;
                  let chosen = lines[0] || '';
                  for (const ln of lines) {
                    if (pos <= acc + ln.length) {
                      chosen = ln;
                      break;
                    }
                    acc += ln.length + 1;
                  }
                  if (chosen.trim()) void dispatchMaki('addTodo', { title: chosen });
                }
              }}
              placeholder="Tulis catatan kilat, ide, atau draf di sini..."
              style={{
                flex: 1,
                resize: 'none',
                background: 'rgba(255,255,255,0.05)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 10,
                padding: '7px 9px',
                color: '#fff',
                fontSize: 10.2,
                outline: 'none',
              }}
            />
          </div>
        )}

        {/* To-Do List (Can take 50% or 100% full maximized width!) */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'nowrap' }}>
            <span style={{ fontSize: 10, fontWeight: 700, color: '#4ade80', whiteSpace: 'nowrap', flexShrink: 0 }}>
              ✓ To-Do ({state.todos.filter((t) => !t.isDone).length})
            </span>
            {state.notesToast && (
              <span style={{ fontSize: 8.5, color: '#fb923c', whiteSpace: 'nowrap' }}>{state.notesToast}</span>
            )}
            <div style={{ flex: 1 }} />

            {/* Maximize / Restore Toggle Button */}
            <button
              onClick={() => setIsTodoMaximized(!isTodoMaximized)}
              style={{
                fontSize: 8.5,
                fontWeight: 600,
                padding: '2px 7px',
                borderRadius: 99,
                background: isTodoMaximized ? 'rgba(34, 197, 94, 0.22)' : 'rgba(255, 255, 255, 0.10)',
                color: isTodoMaximized ? '#4ade80' : 'rgba(255, 255, 255, 0.85)',
                border: '0.8px solid rgba(255, 255, 255, 0.12)',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: 3,
                whiteSpace: 'nowrap',
                flexShrink: 0,
              }}
              title={isTodoMaximized ? 'Kembali ke tampilan bagi layar' : 'Maksimalkan To-Do satu layar penuh agar tulisan panjang terbaca semua'}
            >
              {isTodoMaximized ? '⤡ Bagi' : '⤢ Penuh'}
            </button>

            {state.todos.some((t) => t.isDone) && (
              <button
                onClick={() => void dispatchMaki('clearCompletedTodos')}
                style={{ fontSize: 8.5, color: 'rgba(255,255,255,0.5)', cursor: 'pointer', whiteSpace: 'nowrap', flexShrink: 0 }}
              >
                Bersihkan ✓
              </button>
            )}
          </div>

          <div
            style={{
              flex: 1,
              overflowY: 'auto',
              background: 'rgba(255,255,255,0.04)',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: 10,
              padding: '5px 7px',
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            {state.todos.map((t, idx) => (
              <div
                key={t.id}
                style={{
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: 6,
                  fontSize: 9.8,
                  padding: '3px 6px',
                  borderRadius: 6,
                  background: 'rgba(255, 255, 255, 0.03)',
                }}
              >
                <button
                  onClick={() => void dispatchMaki('toggleTodo', { id: t.id })}
                  style={{
                    width: 14,
                    height: 14,
                    minWidth: 14,
                    borderRadius: 4,
                    border: '1px solid rgba(255,255,255,0.35)',
                    background: t.isDone ? '#22c55e' : 'transparent',
                    fontSize: 9,
                    color: '#000',
                    fontWeight: 800,
                    marginTop: 2,
                    cursor: 'pointer',
                  }}
                >
                  {t.isDone ? '✓' : ''}
                </button>
                <span
                  onClick={() => void dispatchMaki('toggleTodo', { id: t.id })}
                  style={{
                    flex: 1,
                    cursor: 'pointer',
                    textDecoration: t.isDone ? 'line-through' : 'none',
                    color: t.isDone ? 'rgba(255,255,255,0.4)' : '#fff',
                    wordBreak: 'break-word',
                    lineHeight: 1.35,
                  }}
                >
                  {idx < 9 && (
                    <span style={{ fontSize: 8, color: 'rgba(255,255,255,0.35)', marginRight: 4 }}>
                      Alt+{idx + 1}
                    </span>
                  )}
                  {t.title}
                </span>

                {(t.title.length > 25 || t.title.includes('\n')) && (
                  <button
                    onClick={() => setViewingTodo(t)}
                    style={{ fontSize: 8.5, color: '#22d3ee', padding: '1px 4px', cursor: 'pointer', marginTop: 1 }}
                    title="Buka & baca seluruh teks tugas ini"
                  >
                    🔍
                  </button>
                )}

                <button
                  onClick={() => void dispatchMaki('deleteTodo', { id: t.id })}
                  style={{ fontSize: 9, color: 'rgba(255,255,255,0.35)', cursor: 'pointer', marginTop: 2 }}
                  title="Hapus tugas"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', gap: 4 }}>
            <input
              value={todoInput}
              onChange={(e) => setTodoInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && todoInput.trim()) {
                  void dispatchMaki('addTodo', { title: todoInput });
                  setTodoInput('');
                }
              }}
              placeholder="Tambah tugas baru..."
              style={{
                flex: 1,
                background: 'rgba(255,255,255,0.07)',
                border: '1px solid rgba(255,255,255,0.12)',
                borderRadius: 99,
                padding: '4px 9px',
                color: '#fff',
                fontSize: 9.5,
                outline: 'none',
              }}
            />
            <button
              className="pill-btn"
              onClick={() => {
                if (todoInput.trim()) {
                  void dispatchMaki('addTodo', { title: todoInput });
                  setTodoInput('');
                }
              }}
            >
              +
            </button>
          </div>
        </div>
      </div>

      {/* Full-Text Todo Detail Modal for Long Tasks */}
      {viewingTodo && (
        <div
          onClick={() => setViewingTodo(null)}
          style={{
            position: 'absolute',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.65)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 10,
            zIndex: 100,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 380,
              background: 'rgba(26, 18, 12, 0.98)',
              border: '1px solid rgba(255, 255, 255, 0.18)',
              borderRadius: 14,
              padding: '10px 12px',
              display: 'flex',
              flexDirection: 'column',
              gap: 8,
              boxShadow: '0 16px 40px rgba(0, 0, 0, 0.5)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: 10.5, fontWeight: 700, color: '#22d3ee' }}>📋 Detail Tugas To-Do</span>
              <div style={{ flex: 1 }} />
              <button
                onClick={() => {
                  void dispatchMaki('toggleTodo', { id: viewingTodo.id });
                  setViewingTodo({ ...viewingTodo, isDone: !viewingTodo.isDone });
                }}
                style={{
                  fontSize: 8.5,
                  fontWeight: 700,
                  padding: '2.5px 7px',
                  borderRadius: 99,
                  background: viewingTodo.isDone ? 'rgba(34, 197, 94, 0.22)' : 'rgba(255, 255, 255, 0.10)',
                  color: viewingTodo.isDone ? '#4ade80' : 'rgba(255, 255, 255, 0.85)',
                  cursor: 'pointer',
                  border: 'none',
                }}
              >
                {viewingTodo.isDone ? '✓ Selesai' : 'Tandai Selesai'}
              </button>
              <button
                onClick={() => setViewingTodo(null)}
                style={{ color: 'rgba(255, 255, 255, 0.6)', fontSize: 13, cursor: 'pointer', background: 'none', border: 'none' }}
              >
                ✕
              </button>
            </div>

            <div
              className="maki-selectable"
              style={{
                maxHeight: 120,
                overflowY: 'auto',
                background: 'rgba(255, 255, 255, 0.05)',
                border: '1px solid rgba(255, 255, 255, 0.08)',
                borderRadius: 8,
                padding: '6px 8px',
                fontSize: 10.2,
                color: '#fff',
                lineHeight: 1.45,
                wordBreak: 'break-word',
                userSelect: 'text',
              }}
            >
              {viewingTodo.title}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 8.5, color: 'rgba(255, 255, 255, 0.4)' }}>
                {viewingTodo.title.length} karakter
              </span>
              <div style={{ display: 'flex', gap: 6 }}>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(viewingTodo.title);
                  }}
                  style={{
                    fontSize: 8.5,
                    fontWeight: 600,
                    padding: '2.5px 8px',
                    borderRadius: 99,
                    background: 'rgba(6, 182, 212, 0.20)',
                    color: '#22d3ee',
                    cursor: 'pointer',
                    border: 'none',
                  }}
                >
                  📋 Salin Teks
                </button>
                <button
                  onClick={() => setViewingTodo(null)}
                  style={{
                    fontSize: 8.5,
                    fontWeight: 700,
                    padding: '2.5px 8px',
                    borderRadius: 99,
                    background: 'rgba(255, 255, 255, 0.12)',
                    color: '#fff',
                    cursor: 'pointer',
                    border: 'none',
                  }}
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// 4. 🚀 Quick Launch Tab
export const LauncherTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [addingUrl, setAddingUrl] = useState(false);
  const [urlName, setUrlName] = useState('');
  const [urlVal, setUrlVal] = useState('');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7, width: '100%', height: '100%' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 10, fontWeight: 700, color: '#22d3ee' }}>
          🚀 Pintasan Aplikasi & Web Windows
        </span>
        <div style={{ flex: 1 }} />
        <button className="pill-btn" onClick={() => void dispatchMaki('pickLauncherApp')}>
          + Aplikasi / Folder
        </button>
        <button className="pill-btn" onClick={() => setAddingUrl((v) => !v)}>
          + Link Web
        </button>
      </div>

      {addingUrl ? (
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: 6 }}>
          <input
            value={urlName}
            onChange={(e) => setUrlName(e.target.value)}
            placeholder="Nama (mis. Notion)"
            style={{
              width: 130,
              background: 'rgba(255,255,255,0.08)',
              border: '1px solid rgba(255,255,255,0.15)',
              borderRadius: 8,
              padding: '5px 8px',
              color: '#fff',
              fontSize: 9.5,
            }}
          />
          <input
            value={urlVal}
            onChange={(e) => setUrlVal(e.target.value)}
            placeholder="https://notion.so"
            style={{
              flex: 1,
              background: 'rgba(255,255,255,0.08)',
              border: '1px solid rgba(255,255,255,0.15)',
              borderRadius: 8,
              padding: '5px 8px',
              color: '#fff',
              fontSize: 9.5,
            }}
          />
          <button
            className="pill-btn"
            onClick={() => {
              if (urlName.trim() && urlVal.trim()) {
                void dispatchMaki('addLauncherUrl', { name: urlName, url: urlVal });
                setUrlName('');
                setUrlVal('');
                setAddingUrl(false);
              }
            }}
            style={{ background: 'rgba(34,197,94,0.28)', color: '#4ade80' }}
          >
            Tambah
          </button>
        </div>
      ) : (
        <div
          style={{
            display: 'flex',
            gap: 8,
            overflowX: 'auto',
            paddingBottom: 4,
            alignItems: 'center',
            flex: 1,
          }}
        >
          {state.launcherItems.map((item) => (
            <div
              key={item.id}
              onClick={() => void dispatchMaki('launchItem', { id: item.id })}
              onContextMenu={(e) => {
                e.preventDefault();
                void dispatchMaki('removeLauncherItem', { id: item.id });
              }}
              title={`${item.name} • Klik Kanan untuk hapus`}
              style={{
                width: 68,
                height: 68,
                flexShrink: 0,
                borderRadius: 12,
                background: 'rgba(255,255,255,0.06)',
                border: '1px solid rgba(255,255,255,0.09)',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 5,
                cursor: 'pointer',
                padding: 4,
              }}
            >
              {item.iconDataUrl ? (
                <img src={item.iconDataUrl} alt={item.name} style={{ width: 26, height: 26 }} />
              ) : (
                <span style={{ fontSize: 20 }}>{item.iconEmoji}</span>
              )}
              <span
                style={{
                  fontSize: 9,
                  fontWeight: 600,
                  width: '100%',
                  textAlign: 'center',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {item.name}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// 5. 📥 Tray & Offline PDF / Image Studio Tab
export const TrayTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [dropActive, setDropActive] = useState(false);
  const [splitRange, setSplitRange] = useState('1-2');
  const [wmText, setWmText] = useState('CONFIDENTIAL');
  const [renameVal, setRenameVal] = useState('');

  const studioItem = state.droppedItems.find((i) => i.id === state.activeStudioItemId) || null;
  const mergeableCount = state.droppedItems.filter(
    (i) => i.kind === 'pdf' || i.kind === 'image'
  ).length;

  if (studioItem) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 7, width: '100%', height: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('openStudioItem', { id: null })}
          >
            ← Kembali ke Tray
          </button>
          <span
            style={{
              fontSize: 10.5,
              fontWeight: 700,
              flex: 1,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            🛠️ Studio: {studioItem.name} ({studioItem.badgeText})
          </span>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('revealTrayItem', { id: studioItem.id })}
          >
            📂 Explorer
          </button>
        </div>

        {/* Rename Row */}
        <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
          <input
            value={renameVal}
            onChange={(e) => setRenameVal(e.target.value)}
            placeholder={`Ganti nama (${studioItem.name})...`}
            style={{
              flex: 1,
              background: 'rgba(255,255,255,0.07)',
              border: '1px solid rgba(255,255,255,0.14)',
              borderRadius: 8,
              padding: '4px 8px',
              color: '#fff',
              fontSize: 9.5,
            }}
          />
          <button
            className="pill-btn"
            onClick={() => {
              if (renameVal.trim()) {
                void dispatchMaki('renameTrayItem', { id: studioItem.id, newName: renameVal });
                setRenameVal('');
              }
            }}
          >
            Ubah Nama
          </button>
        </div>

        {studioItem.kind === 'pdf' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div style={{ display: 'flex', gap: 5, alignItems: 'center', flexWrap: 'wrap' }}>
              <span style={{ fontSize: 9.2, color: 'rgba(255,255,255,0.65)' }}>Putar PDF:</span>
              {[90, 180, 270].map((deg) => (
                <button
                  key={deg}
                  className="pill-btn"
                  disabled={state.trayBusy}
                  onClick={() => void dispatchMaki('rotatePdf', { id: studioItem.id, angle: deg })}
                >
                  ↻ {deg}°
                </button>
              ))}
            </div>

            <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
              <span style={{ fontSize: 9.2, color: 'rgba(255,255,255,0.65)' }}>Potong Hal:</span>
              <input
                value={splitRange}
                onChange={(e) => setSplitRange(e.target.value)}
                placeholder="mis. 1-3, 5"
                style={{
                  width: 90,
                  background: 'rgba(255,255,255,0.07)',
                  border: '1px solid rgba(255,255,255,0.14)',
                  borderRadius: 7,
                  padding: '3px 7px',
                  color: '#fff',
                  fontSize: 9.2,
                }}
              />
              <button
                className="pill-btn"
                disabled={state.trayBusy}
                onClick={() =>
                  void dispatchMaki('splitPdf', { id: studioItem.id, range: splitRange })
                }
              >
                ✂️ Ekstrak PDF
              </button>
            </div>

            <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
              <span style={{ fontSize: 9.2, color: 'rgba(255,255,255,0.65)' }}>Watermark:</span>
              <input
                value={wmText}
                onChange={(e) => setWmText(e.target.value)}
                style={{
                  flex: 1,
                  background: 'rgba(255,255,255,0.07)',
                  border: '1px solid rgba(255,255,255,0.14)',
                  borderRadius: 7,
                  padding: '3px 7px',
                  color: '#fff',
                  fontSize: 9.2,
                }}
              />
              <button
                className="pill-btn"
                disabled={state.trayBusy}
                onClick={() =>
                  void dispatchMaki('watermarkPdf', { id: studioItem.id, text: wmText })
                }
              >
                💧 Cap Teks
              </button>
            </div>
          </div>
        )}

        {studioItem.kind === 'image' && (
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            <span style={{ fontSize: 9.2, color: 'rgba(255,255,255,0.65)' }}>Konversi Gambar:</span>
            <button
              className="pill-btn"
              onClick={() =>
                void dispatchMaki('convertImage', { id: studioItem.id, format: 'png' })
              }
            >
              🖼️ Jadikan PNG
            </button>
            <button
              className="pill-btn"
              onClick={() =>
                void dispatchMaki('convertImage', { id: studioItem.id, format: 'jpg' })
              }
            >
              🖼️ Jadikan JPG
            </button>
            <button
              className="pill-btn"
              onClick={() => void dispatchMaki('askMakiAboutItem', { id: studioItem.id })}
              style={{ background: 'rgba(251,146,60,0.24)', color: '#fb923c' }}
            >
              💬 Tanya Maki AI soal Gambar Ini
            </button>
          </div>
        )}

        {state.trayBanner && (
          <div
            style={{
              fontSize: 9.2,
              color: state.trayBanner.isError ? '#f87171' : '#4ade80',
              fontWeight: 600,
            }}
          >
            {state.trayBanner.message}
          </div>
        )}
      </div>
    );
  }

  return (
    <div
      onDragOver={(e) => {
        e.preventDefault();
        setDropActive(true);
        window.maki.setDropHold(true);
      }}
      onDragLeave={() => {
        setDropActive(false);
        window.maki.setDropHold(false);
      }}
      onDrop={(e) => {
        e.preventDefault();
        setDropActive(false);
        window.maki.setDropHold(false);
        const paths = extractDroppedFilePaths(e);
        if (paths.length > 0) void dispatchMaki('dropFiles', { paths });
      }}
      style={{ display: 'flex', flexDirection: 'column', gap: 7, width: '100%', height: '100%' }}
    >
      {state.droppedItems.length === 0 ? (
        <div
          style={{
            flex: 1,
            borderRadius: 13,
            border: `1.5px dashed ${dropActive ? '#22d3ee' : 'rgba(255,255,255,0.2)'}`,
            background: dropActive ? 'rgba(59,130,246,0.16)' : 'rgba(255,255,255,0.04)',
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            padding: '0 14px',
          }}
        >
          <span style={{ fontSize: 22 }}>📥</span>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, fontWeight: 700 }}>
              Kasih Screenshot (Win+Shift+S) atau File ke Maki / Tray
            </div>
            <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.52)' }}>
              Tarik file dari Explorer ke Maki biar masuk Tray & siap ditarik keluar kapan saja
            </div>
          </div>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('grabScreenshot')}
            style={{ background: 'rgba(251,146,60,0.26)', color: '#fb923c' }}
          >
            📸 Screenshot
          </button>
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('pickTrayFiles')}
            style={{ background: 'rgba(59,130,246,0.30)', color: '#22d3ee' }}
          >
            + Pilih File
          </button>
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', gap: 8, overflowX: 'auto', flex: 1, alignItems: 'center' }}>
            {state.droppedItems.map((item: DroppedItem) => (
              <div
                key={item.id}
                draggable
                onDragStart={(e) => {
                  e.preventDefault();
                  window.maki.startNativeFileDrag(item.path);
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '6px 9px',
                  borderRadius: 11,
                  background: 'rgba(255,255,255,0.07)',
                  border: '1px solid rgba(255,255,255,0.12)',
                  flexShrink: 0,
                  cursor: 'grab',
                }}
                title="Tarik keluar langsung ke Explorer / WhatsApp / Aplikasi lain!"
              >
                {item.thumbnailDataUrl ? (
                  <img
                    src={item.thumbnailDataUrl}
                    alt={item.name}
                    style={{ width: 34, height: 28, objectFit: 'cover', borderRadius: 5 }}
                  />
                ) : (
                  <span style={{ fontSize: 18 }}>{item.kind === 'pdf' ? '📕' : '📄'}</span>
                )}
                <div style={{ maxWidth: 112 }}>
                  <div
                    style={{
                      fontSize: 10,
                      fontWeight: 600,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {item.name}
                  </div>
                  <div style={{ fontSize: 8.5, color: '#22d3ee' }}>
                    {item.badgeText} • {item.sizeFormatted}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 3 }}>
                  <button
                    className="pill-btn"
                    style={{ padding: '2px 6px' }}
                    onClick={() => void dispatchMaki('copyTrayItem', { id: item.id })}
                  >
                    Salin
                  </button>
                  {item.kind === 'image' && (
                    <button
                      className="pill-btn"
                      style={{ padding: '2px 5px', background: 'rgba(251,146,60,0.22)' }}
                      onClick={() => void dispatchMaki('askMakiAboutItem', { id: item.id })}
                      title="Tanya Maki AI tentang gambar ini"
                    >
                      💬
                    </button>
                  )}
                  <button
                    className="pill-btn"
                    style={{ padding: '2px 6px' }}
                    onClick={() => void dispatchMaki('openStudioItem', { id: item.id })}
                  >
                    Studio
                  </button>
                  <button
                    onClick={() => void dispatchMaki('removeTrayItem', { id: item.id })}
                    style={{ fontSize: 9.5, color: 'rgba(255,255,255,0.45)', padding: '0 3px' }}
                  >
                    ✕
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontSize: 9, color: 'rgba(255,255,255,0.5)' }}>
              {state.droppedItems.length} item • Tarik keluar ke Explorer atau klik Studio
            </span>
            {state.trayBanner && (
              <span
                style={{
                  fontSize: 9,
                  fontWeight: 600,
                  color: state.trayBanner.isError ? '#f87171' : '#4ade80',
                }}
              >
                • {state.trayBanner.message}
              </span>
            )}
            <div style={{ flex: 1 }} />
            <button
              className="pill-btn"
              onClick={() => void dispatchMaki('grabScreenshot')}
              style={{ background: 'rgba(251,146,60,0.22)', color: '#fb923c' }}
            >
              📸 Screenshot
            </button>
            <button className="pill-btn" onClick={() => void dispatchMaki('pickTrayFiles')}>
              + Tambah
            </button>
            {mergeableCount >= 2 && (
              <button
                className="pill-btn"
                disabled={state.trayBusy}
                onClick={() => void dispatchMaki('mergeTrayPdf')}
                style={{ background: 'rgba(59,130,246,0.32)', color: '#22d3ee' }}
              >
                📑 Gabung PDF ({mergeableCount})
              </button>
            )}
            <button className="pill-btn" onClick={() => void dispatchMaki('zipTray')}>
              🗜️ ZIP
            </button>
            <button
              onClick={() => void dispatchMaki('clearTray')}
              style={{ fontSize: 9.2, color: '#f87171' }}
            >
              Hapus Semua
            </button>
          </div>
        </>
      )}
    </div>
  );
};

// 6. 📊 System Monitor Tab
export const SystemTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const s = state.system;
  const cc = state.cacheCleaner || {
    isScanning: false,
    isCleaning: false,
    totalSafeBytes: 0,
    formattedSafeSize: '0 KB',
    lastFreedBytes: 0,
    formattedFreedSize: '0 KB',
    progressText: '',
    hasCompletedInitialScan: false,
  };

  const cards = [
    {
      title: 'CPU Windows',
      val: `${s.cpuPercent}%`,
      pct: s.cpuPercent,
      sub: s.cpuPercent >= 65 ? 'Beban Tinggi' : 'Adem & Stabil',
      color: s.cpuPercent >= 75 ? '#ef4444' : '#3b82f6',
    },
    {
      title: 'Memori RAM',
      val: `${s.ramUsedGB} / ${s.ramTotalGB} GB`,
      pct: s.ramPercent,
      sub: `Terpakai ${s.ramPercent}%`,
      color: '#a855f7',
    },
    {
      title: 'Daya / Baterai',
      val: s.hasBattery ? `${s.batteryLevel}%` : 'AC Desktop',
      pct: s.batteryLevel,
      sub: s.isCharging ? '⚡ Mengisi Daya / AC' : 'Mode Baterai',
      color: '#22c55e',
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7, width: '100%', height: '100%', justifyContent: 'center' }}>
      {/* Top Row: System Metrics */}
      <div style={{ display: 'flex', gap: 9, width: '100%', alignItems: 'center' }}>
        {cards.map((c) => (
          <div
            key={c.title}
            style={{
              flex: 1,
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.09)',
              borderRadius: 12,
              padding: '7px 11px',
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            <div style={{ fontSize: 9.2, color: 'rgba(255,255,255,0.6)', fontWeight: 600 }}>
              {c.title}
            </div>
            <div style={{ fontSize: 13, fontWeight: 800 }}>{c.val}</div>
            <div style={{ height: 4, borderRadius: 99, background: 'rgba(255,255,255,0.1)' }}>
              <div
                style={{
                  width: `${Math.max(3, Math.min(100, c.pct))}%`,
                  height: '100%',
                  borderRadius: 99,
                  background: c.color,
                }}
              />
            </div>
            <div style={{ fontSize: 8.5, color: 'rgba(255,255,255,0.5)' }}>{c.sub}</div>
          </div>
        ))}
      </div>

      {/* Bottom Card: Maki Cache Cleaner (Opsi 2) */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '6px 10px',
          background: 'rgba(255,255,255,0.04)',
          border: '1px solid rgba(255,255,255,0.08)',
          borderRadius: 11,
          gap: 10,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0, flex: 1 }}>
          <div
            style={{
              width: 24,
              height: 24,
              borderRadius: 99,
              background: 'rgba(249, 115, 22, 0.20)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 12,
              flexShrink: 0,
            }}
          >
            ✨
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: '#fff' }}>
                Pembersih Cache Aman (Maki Clean)
              </span>
              <span
                style={{
                  fontSize: 7.8,
                  padding: '1px 5px',
                  borderRadius: 4,
                  background: 'rgba(34, 197, 94, 0.16)',
                  color: '#4ade80',
                  fontWeight: 600,
                }}
              >
                Recycle Bin
              </span>
            </div>
            <div
              style={{
                fontSize: 8.5,
                color: cc.isCleaning ? '#fb923c' : cc.lastFreedBytes > 0 ? '#4ade80' : 'rgba(255,255,255,0.65)',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {cc.isScanning
                ? (cc.progressText || 'Memindai cache...')
                : cc.isCleaning
                ? (cc.progressText || 'Memindahkan ke Recycle Bin...')
                : cc.lastFreedBytes > 0
                ? `Baru dibersihkan: ${cc.formattedFreedSize} dibuang ke Recycle Bin ✨`
                : `${cc.formattedSafeSize} cache aman terdeteksi (Temp, Chrome/Edge, npm)`}
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0 }}>
          {/* Refresh / Rescan Button */}
          <button
            onClick={() => void dispatchMaki('scanCache')}
            disabled={cc.isScanning || cc.isCleaning}
            title="Pindai ulang cache"
            style={{
              width: 24,
              height: 24,
              borderRadius: 99,
              background: 'rgba(255,255,255,0.08)',
              border: 'none',
              color: '#fff',
              fontSize: 11,
              cursor: (cc.isScanning || cc.isCleaning) ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              opacity: (cc.isScanning || cc.isCleaning) ? 0.4 : 1,
            }}
          >
            🔄
          </button>

          {/* Clean Button */}
          <button
            onClick={() => void dispatchMaki('cleanCache')}
            disabled={cc.isCleaning || cc.totalSafeBytes === 0}
            title="Pindahkan cache aman ke Recycle Bin"
            style={{
              padding: '4px 10px',
              borderRadius: 8,
              background: (cc.totalSafeBytes === 0 || cc.isCleaning)
                ? 'rgba(255,255,255,0.06)'
                : 'linear-gradient(135deg, #ea580c, #f97316)',
              border: 'none',
              color: '#fff',
              fontSize: 9.5,
              fontWeight: 700,
              cursor: (cc.totalSafeBytes === 0 || cc.isCleaning) ? 'not-allowed' : 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              opacity: (cc.totalSafeBytes === 0 || cc.isCleaning) ? 0.45 : 1,
            }}
          >
            <span>🧹</span>
            <span>{cc.isCleaning ? 'Menyapu...' : 'Sapu Aman'}</span>
          </button>
        </div>
      </div>
    </div>
  );
};

// 7. 📋 Clipboard History Tab
export const ClipboardTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [query, setQuery] = useState('');
  const filtered = state.clipboardHistory.filter((c) =>
    c.text.toLowerCase().includes(query.toLowerCase())
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.altKey && e.key >= '1' && e.key <= '9') {
        const item = filtered[Number(e.key) - 1];
        if (item) {
          e.preventDefault();
          void dispatchMaki('copyClipboardEntry', { id: item.id });
        }
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [filtered]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, width: '100%', height: '100%' }}>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="🔍 Cari riwayat teks / screenshot clipboard..."
          style={{
            flex: 1,
            background: 'rgba(255,255,255,0.07)',
            border: '1px solid rgba(255,255,255,0.12)',
            borderRadius: 99,
            padding: '4px 10px',
            color: '#fff',
            fontSize: 9.5,
            outline: 'none',
          }}
        />
        {state.clipboardHistory.length > 0 && (
          <button
            className="pill-btn"
            onClick={() => void dispatchMaki('clearClipboardHistory')}
            style={{ color: '#f87171' }}
          >
            Bersihkan
          </button>
        )}
      </div>

      <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 4 }}>
        {filtered.length === 0 ? (
          <div style={{ fontSize: 9.5, color: 'rgba(255,255,255,0.45)', marginTop: 12 }}>
            Belum ada riwayat salinan — tekan Ctrl+C atau Win+Shift+S otomatis tercatat 24/7!
          </div>
        ) : (
          filtered.map((c, idx) => (
            <div
              key={c.id}
              onClick={() => void dispatchMaki('copyClipboardEntry', { id: c.id })}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '5px 8px',
                borderRadius: 9,
                background: 'rgba(255,255,255,0.05)',
                cursor: 'pointer',
              }}
            >
              {idx < 9 && (
                <span style={{ fontSize: 8, color: '#a855f7', fontWeight: 700 }}>Alt+{idx + 1}</span>
              )}
              {c.previewDataUrl && (
                <img
                  src={c.previewDataUrl}
                  alt="clip"
                  style={{ width: 28, height: 22, objectFit: 'cover', borderRadius: 4 }}
                />
              )}
              <span
                style={{
                  flex: 1,
                  fontSize: 9.8,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {c.text}
              </span>
              <span style={{ fontSize: 8.5, color: 'rgba(255,255,255,0.4)' }}>{c.timestamp}</span>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

// 8. ⏳ Focus Timer Tab
export const TimerTab: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [customMin, setCustomMin] = useState('25');
  const tm = state.timer;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, width: '100%', height: '100%' }}>
      <div
        style={{
          width: 82,
          height: 82,
          borderRadius: 99,
          border: `4px solid ${tm.isTimeUpAlert ? '#ef4444' : 'rgba(251,146,60,0.35)'}`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
          background: 'rgba(255,255,255,0.04)',
        }}
      >
        <div style={{ fontSize: 16, fontWeight: 800, fontVariantNumeric: 'tabular-nums' }}>
          {tm.totalSeconds > 0 ? tm.formattedTime : '00:00'}
        </div>
        <div style={{ fontSize: 8, color: '#fb923c' }}>
          {tm.isTimeUpAlert ? 'SELESAI!' : tm.isRunning ? 'FOKUS' : 'SIAP'}
        </div>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 7 }}>
        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
          {[5, 15, 25, 45].map((m) => (
            <button
              key={m}
              className="pill-btn"
              onClick={() => void dispatchMaki('startTimer', { seconds: m * 60 })}
            >
              ⏱️ {m} Menit
            </button>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <input
            value={customMin}
            onChange={(e) => setCustomMin(e.target.value)}
            style={{
              width: 52,
              background: 'rgba(255,255,255,0.08)',
              border: '1px solid rgba(255,255,255,0.14)',
              borderRadius: 7,
              padding: '4px 7px',
              color: '#fff',
              fontSize: 9.5,
            }}
          />
          <button
            className="pill-btn"
            onClick={() =>
              void dispatchMaki('startTimer', {
                seconds: Math.max(1, Number(customMin) || 25) * 60,
              })
            }
            style={{ background: 'rgba(251,146,60,0.28)', color: '#fb923c' }}
          >
            Mulai Kustom (menit)
          </button>

          {tm.totalSeconds > 0 && (
            <>
              <button className="pill-btn" onClick={() => void dispatchMaki('toggleTimerPause')}>
                {tm.isRunning ? '⏸ Jeda' : '▶ Lanjut'}
              </button>
              <button
                className="pill-btn"
                onClick={() => void dispatchMaki('resetTimer')}
                style={{ color: '#f87171' }}
              >
                Reset
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
