import React, { useEffect, useRef, useState } from 'react';
import {
  AI_PROVIDERS,
  ALL_AI_MODELS,
  MakiAIProvider,
  MakiChatMessage,
  SharedAppState,
} from '../../shared/types';
import { dispatchMaki, extractDroppedFilePaths } from '../bridge';

function formatMessageHtml(raw: string, isLight: boolean): React.ReactNode {
  const lines = raw.split(/\r?\n/);
  return lines.map((line, idx) => {
    const parts = line.split(/(\*\*[^*]+\*\*|`[^`]+`)/g);
    return (
      <React.Fragment key={idx}>
        {parts.map((part, pIdx) => {
          if (part.startsWith('**') && part.endsWith('**')) {
            return <strong key={pIdx}>{part.slice(2, -2)}</strong>;
          }
          if (part.startsWith('`') && part.endsWith('`')) {
            return (
              <code
                key={pIdx}
                style={{
                  background: isLight ? 'rgba(65, 38, 18, 0.08)' : 'rgba(255,255,255,0.12)',
                  color: isLight ? '#9a3412' : '#fed7aa',
                  padding: '1px 4.5px',
                  borderRadius: 4,
                  fontFamily: 'Consolas, monospace',
                  fontSize: '0.92em',
                }}
              >
                {part.slice(1, -1)}
              </code>
            );
          }
          return <span key={pIdx}>{part}</span>;
        })}
        {idx < lines.length - 1 && <br />}
      </React.Fragment>
    );
  });
}

export const MakiChatBody: React.FC<{
  state: SharedAppState;
  compactDesktop?: boolean;
  theme?: 'light' | 'dark';
}> = ({ state, compactDesktop = false, theme }) => {
  const isLight = theme ? theme === 'light' : compactDesktop;
  const [draft, setDraft] = useState('');
  const [keyInput, setKeyInput] = useState('');
  const [providerTab, setProviderTab] = useState<MakiAIProvider>(state.selectedProvider || 'gemini');
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [dropActive, setDropActive] = useState(false);
  const scrollRef = useRef<HTMLDivElement | null>(null);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const prevMsgCountRef = useRef(0);

  useEffect(() => {
    if (state.selectedProvider) {
      setProviderTab(state.selectedProvider);
    }
  }, [state.selectedProvider]);

  useEffect(() => {
    if (!scrollRef.current) return;
    const isNewMessage = state.messages.length > prevMsgCountRef.current;
    prevMsgCountRef.current = state.messages.length;

    if (isNewMessage && state.messages.length > 0) {
      const last = state.messages[state.messages.length - 1];
      if (last.sender === 'user') {
        scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
      } else {
        const el = document.getElementById(`maki-msg-${last.id}`);
        if (el) {
          el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        } else {
          scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
      }
    } else if (state.isThinking) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [state.messages.length, state.isThinking]);

  useEffect(() => {
    if (!state.isShowingGeminiSettings) {
      setTimeout(() => inputRef.current?.focus(), 80);
    }
  }, [state.isShowingGeminiSettings]);

  const sendNow = () => {
    if (!draft.trim() && !state.pendingAttachment) return;
    const text = draft;
    setDraft('');
    void dispatchMaki('sendGeminiMessage', { text });
  };

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
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 6,
        width: '100%',
        height: '100%',
        minHeight: 0,
      }}
    >
      {/* Header Bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <span
          style={{
            fontSize: 11,
            fontWeight: 800,
            color: isLight ? '#2c180d' : '#ffffff',
            letterSpacing: 0.2,
          }}
        >
          💬 Tanya Maki
        </span>

        <select
          value={state.selectedModel}
          onChange={(e) => void dispatchMaki('setGeminiModel', { model: e.target.value })}
          style={{
            background: isLight ? 'rgba(234, 88, 12, 0.10)' : 'rgba(255, 255, 255, 0.10)',
            color: isLight ? '#c2410c' : '#fb923c',
            border: isLight
              ? '0.8px solid rgba(234, 88, 12, 0.28)'
              : '0.8px solid rgba(255, 255, 255, 0.14)',
            borderRadius: 99,
            fontSize: 9,
            fontWeight: 700,
            padding: '2px 6.5px',
            outline: 'none',
            cursor: 'pointer',
            maxWidth: 150,
          }}
        >
          {AI_PROVIDERS.map((prov) => {
            const models = ALL_AI_MODELS.filter((m) => m.provider === prov.id);
            if (models.length === 0) return null;
            return (
              <optgroup
                key={prov.id}
                label={`${prov.icon} ${prov.name}`}
                style={{
                  background: isLight ? '#fef3c7' : '#1f130a',
                  color: isLight ? '#9a3412' : '#fb923c',
                  fontWeight: 800,
                }}
              >
                {models.map((m) => (
                  <option
                    key={m.id}
                    value={m.id}
                    style={{
                      background: isLight ? '#FFFDF8' : '#241a12',
                      color: isLight ? '#2c180d' : '#ffffff',
                      fontWeight: 500,
                    }}
                  >
                    {m.shortLabel}
                  </option>
                ))}
              </optgroup>
            );
          })}
        </select>

        <div style={{ flex: 1 }} />

        <button
          className="pill-btn"
          title="Lampirkan Screenshot dari Clipboard / Terakhir"
          onClick={() => void dispatchMaki('attachScreenshotToGemini')}
          style={{
            background: isLight ? 'rgba(6, 182, 212, 0.10)' : 'rgba(255, 255, 255, 0.08)',
            color: '#0891b2',
            border: isLight
              ? '0.8px solid rgba(6, 182, 212, 0.28)'
              : '0.8px solid rgba(255, 255, 255, 0.12)',
            padding: '2.5px 6.5px',
            borderRadius: 99,
          }}
        >
          📸 {!compactDesktop && 'Screenshot'}
        </button>

        {state.messages.length > 0 && (
          <button
            className="pill-btn"
            title="Mulai obrolan baru"
            onClick={() => void dispatchMaki('newGeminiConversation')}
            style={{
              background: isLight ? 'rgba(65, 38, 18, 0.08)' : 'rgba(255, 255, 255, 0.08)',
              color: isLight ? '#4a2c16' : 'rgba(255, 255, 255, 0.85)',
              border: isLight
                ? '0.8px solid rgba(65, 38, 18, 0.18)'
                : '0.8px solid rgba(255, 255, 255, 0.12)',
              padding: '2.5px 6px',
              borderRadius: 99,
            }}
          >
            ↺
          </button>
        )}

        <button
          className="pill-btn"
          title={`Pengaturan API Key Gemini (${state.maskedAPIKey})`}
          onClick={() => void dispatchMaki('toggleGeminiSettings')}
          style={{
            padding: '2.5px 6px',
            borderRadius: 99,
            background: state.isShowingGeminiSettings
              ? isLight
                ? 'rgba(234, 88, 12, 0.18)'
                : 'rgba(251, 146, 60, 0.25)'
              : isLight
              ? 'rgba(65, 38, 18, 0.08)'
              : 'rgba(255, 255, 255, 0.08)',
            color: state.hasAPIKey ? '#16a34a' : '#ea580c',
            border: isLight
              ? '0.8px solid rgba(65, 38, 18, 0.18)'
              : '0.8px solid rgba(255, 255, 255, 0.12)',
          }}
        >
          <span
            style={{
              width: 5.5,
              height: 5.5,
              borderRadius: 99,
              background: state.hasAPIKey ? '#16a34a' : '#ea580c',
              display: 'inline-block',
            }}
          />
          🔑
        </button>

        <button
          className="pill-btn"
          onClick={() =>
            void dispatchMaki(compactDesktop ? 'toggleDesktopChat' : 'closeNotchChat')
          }
          style={{
            background: compactDesktop
              ? isLight
                ? 'rgba(65, 38, 18, 0.08)'
                : 'rgba(255, 255, 255, 0.08)'
              : 'rgba(22, 163, 74, 0.15)',
            color: compactDesktop ? (isLight ? '#4a2c16' : 'rgba(255, 255, 255, 0.85)') : '#16a34a',
            border: isLight
              ? '0.8px solid rgba(65, 38, 18, 0.18)'
              : '0.8px solid rgba(255, 255, 255, 0.12)',
            padding: '2.5px 7px',
            borderRadius: 99,
          }}
          title={compactDesktop ? 'Tutup chat' : 'Kembali ke Habitat'}
        >
          {compactDesktop ? '✕' : '🌿 Habitat'}
        </button>
      </div>

      {/* Settings Drawer OR Messages Area */}
      {state.isShowingGeminiSettings ? (
        <div
          style={{
            flex: 1,
            background: isLight ? 'rgba(250, 246, 240, 0.98)' : 'rgba(22, 14, 9, 0.85)',
            border: isLight
              ? '1px solid rgba(65, 38, 18, 0.18)'
              : '1px solid rgba(255, 255, 255, 0.10)',
            borderRadius: 12,
            padding: 9,
            display: 'flex',
            flexDirection: 'column',
            gap: 6,
            color: isLight ? '#2c180d' : '#f5efe6',
            overflowY: 'auto',
          }}
        >
          {/* Provider Selection Tabs */}
          <div style={{ display: 'flex', gap: 3.5, overflowX: 'auto', paddingBottom: 2 }}>
            {AI_PROVIDERS.map((prov) => {
              const hasKey = Boolean(state.providerKeyStatuses?.[prov.id]);
              const isActive = providerTab === prov.id;
              return (
                <button
                  key={prov.id}
                  onClick={() => {
                    setProviderTab(prov.id);
                    setKeyInput('');
                  }}
                  style={{
                    fontSize: 8.5,
                    padding: '2.5px 6.5px',
                    borderRadius: 99,
                    background: isActive
                      ? (isLight ? '#ea580c' : '#fb923c')
                      : (isLight ? 'rgba(65, 38, 18, 0.08)' : 'rgba(255, 255, 255, 0.08)'),
                    color: isActive ? '#ffffff' : (isLight ? '#2c180d' : '#f5efe6'),
                    fontWeight: isActive ? 700 : 500,
                    border: 'none',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 3,
                    whiteSpace: 'nowrap',
                  }}
                >
                  <span>{prov.icon}</span>
                  <span>{prov.name}</span>
                  <span
                    style={{
                      width: 4.5,
                      height: 4.5,
                      borderRadius: 99,
                      background: hasKey ? '#22c55e' : (isLight ? 'rgba(0,0,0,0.2)' : 'rgba(255,255,255,0.3)'),
                    }}
                  />
                </button>
              );
            })}
          </div>

          {/* Current Provider Detail & Key Input */}
          {(() => {
            const curMeta = AI_PROVIDERS.find((p) => p.id === providerTab) || AI_PROVIDERS[0];
            const hasThisKey = Boolean(state.providerKeyStatuses?.[curMeta.id]);
            return (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ fontSize: 9.5, fontWeight: 700, color: '#ea580c' }}>
                    {curMeta.icon} {curMeta.name} <span style={{ fontSize: 8, opacity: 0.7 }}>({curMeta.badge})</span>
                  </div>
                  <div
                    style={{
                      fontSize: 8.5,
                      fontWeight: 600,
                      color: hasThisKey ? '#16a34a' : (isLight ? 'rgba(65,38,18,0.6)' : 'rgba(255,255,255,0.6)'),
                    }}
                  >
                    {hasThisKey ? '✓ Aktif' : 'Belum diatur'}
                  </div>
                </div>

                <div style={{ fontSize: 8.5, color: isLight ? 'rgba(65, 38, 18, 0.70)' : 'rgba(255, 255, 255, 0.65)' }}>
                  {curMeta.tip} {curMeta.envVar && <span>(Bisa juga lewat env <code>{curMeta.envVar}</code>)</span>}
                </div>

                <div style={{ display: 'flex', gap: 5 }}>
                  <input
                    type="password"
                    value={keyInput}
                    onChange={(e) => setKeyInput(e.target.value)}
                    placeholder={curMeta.placeholder}
                    style={{
                      flex: 1,
                      background: isLight ? '#ffffff' : 'rgba(14, 9, 6, 0.90)',
                      border: isLight
                        ? '1.2px solid rgba(65, 38, 18, 0.22)'
                        : '1px solid rgba(255, 255, 255, 0.16)',
                      borderRadius: 8,
                      padding: '4px 7px',
                      color: isLight ? '#2c180d' : '#ffffff',
                      fontSize: 9.5,
                      outline: 'none',
                    }}
                  />
                  <button
                    className="pill-btn"
                    onClick={() => {
                      if (keyInput.trim()) {
                        void dispatchMaki('saveGeminiApiKey', { apiKey: keyInput, provider: curMeta.id });
                        setKeyInput('');
                      }
                    }}
                    style={{
                      background: 'rgba(22, 163, 74, 0.16)',
                      color: '#15803d',
                      fontWeight: 700,
                      border: '0.8px solid rgba(22, 163, 74, 0.30)',
                      fontSize: 9,
                      padding: '4px 8px',
                    }}
                  >
                    Simpan
                  </button>
                  {hasThisKey && curMeta.id !== 'ollama' && (
                    <button
                      className="pill-btn"
                      onClick={() => void dispatchMaki('clearGeminiApiKey', { provider: curMeta.id })}
                      style={{
                        background: 'rgba(239, 68, 68, 0.14)',
                        color: '#dc2626',
                        fontWeight: 700,
                        border: '0.8px solid rgba(239, 68, 68, 0.28)',
                        fontSize: 9,
                        padding: '4px 8px',
                      }}
                    >
                      Hapus
                    </button>
                  )}
                </div>

                <div style={{ fontSize: 8, color: isLight ? 'rgba(65, 38, 18, 0.55)' : 'rgba(255, 255, 255, 0.50)' }}>
                  🔒 Kunci disimpan aman secara lokal di AppData komputermu, tidak pernah di-upload ke GitHub atau repo.
                </div>
              </div>
            );
          })()}
        </div>
      ) : (
        <>
          <div
            ref={scrollRef}
            className="maki-chat-scroll"
            style={{
              flex: 1,
              minHeight: 0,
              overflowY: 'auto',
              background: dropActive
                ? isLight
                  ? 'rgba(251, 146, 60, 0.15)'
                  : 'rgba(251, 146, 60, 0.18)'
                : isLight
                ? 'rgba(247, 243, 236, 0.70)'
                : 'rgba(16, 11, 7, 0.45)',
              border: isLight
                ? '1px solid rgba(65, 38, 18, 0.12)'
                : '1px solid rgba(255, 255, 255, 0.08)',
              borderRadius: 12,
              padding: '7px 9px',
              display: 'flex',
              flexDirection: 'column',
              gap: 7,
            }}
          >
            {state.messages.length === 0 && !state.isThinking ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                <div
                  style={{
                    fontSize: 9.8,
                    color: isLight ? '#4a2c16' : 'rgba(255, 255, 255, 0.82)',
                    lineHeight: 1.42,
                    fontWeight: 500,
                  }}
                >
                  Halo! Aku Maki 🐾 Mau tanya jadwal hari ini, minta jelasin screenshot (
                  <code>Win+Shift+S</code>), atau diskusi kode & ide? Tulis aja di bawah!
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
                  <button
                    className="pill-btn"
                    style={{
                      background: isLight ? 'rgba(234, 88, 12, 0.10)' : 'rgba(251, 146, 60, 0.18)',
                      color: isLight ? '#c2410c' : '#fb923c',
                      border: isLight
                        ? '0.8px solid rgba(234, 88, 12, 0.26)'
                        : '0.8px solid rgba(251, 146, 60, 0.35)',
                      fontWeight: 600,
                      borderRadius: 99,
                      padding: '3px 8.5px',
                    }}
                    onClick={() =>
                      void dispatchMaki('sendGeminiMessage', {
                        text: 'Rangkum jadwal kalender hari ini dan tugas To-Do aku yang belum selesai dong.',
                      })
                    }
                  >
                    📅 Jadwal & Tugas
                  </button>
                  <button
                    className="pill-btn"
                    style={{
                      background: isLight ? 'rgba(234, 88, 12, 0.10)' : 'rgba(251, 146, 60, 0.18)',
                      color: isLight ? '#c2410c' : '#fb923c',
                      border: isLight
                        ? '0.8px solid rgba(234, 88, 12, 0.26)'
                        : '0.8px solid rgba(251, 146, 60, 0.35)',
                      fontWeight: 600,
                      borderRadius: 99,
                      padding: '3px 8.5px',
                    }}
                    onClick={async () => {
                      await dispatchMaki('attachScreenshotToGemini');
                      void dispatchMaki('sendGeminiMessage', {
                        text: 'Tolong jelaskan isi screenshot ini secara ringkas dan jelas.',
                      });
                    }}
                  >
                    📸 Jelaskan Screenshot
                  </button>
                  <button
                    className="pill-btn"
                    style={{
                      background: isLight ? 'rgba(234, 88, 12, 0.10)' : 'rgba(251, 146, 60, 0.18)',
                      color: isLight ? '#c2410c' : '#fb923c',
                      border: isLight
                        ? '0.8px solid rgba(234, 88, 12, 0.26)'
                        : '0.8px solid rgba(251, 146, 60, 0.35)',
                      fontWeight: 600,
                      borderRadius: 99,
                      padding: '3px 8.5px',
                    }}
                    onClick={() =>
                      void dispatchMaki('sendGeminiMessage', {
                        text: 'Kamu itu apa? Jelaskan maki-land ini aplikasi apa dan apa saja fitur-fiturnya.',
                      })
                    }
                  >
                    ✨ Maki itu apa?
                  </button>
                </div>
              </div>
            ) : (
              state.messages.map((m: MakiChatMessage) => (
                <div
                  key={m.id}
                  id={`maki-msg-${m.id}`}
                  style={{
                    alignSelf: m.sender === 'user' ? 'flex-end' : 'flex-start',
                    maxWidth: m.sender === 'user' ? '88%' : '94%',
                    padding: '7px 11px',
                    borderRadius:
                      m.sender === 'user'
                        ? '13px 13px 3px 13px'
                        : '13px 13px 13px 3px',
                    background:
                      m.sender === 'user'
                        ? 'linear-gradient(135deg, #f97316, #ea580c)'
                        : m.sender === 'error'
                        ? isLight
                          ? 'rgba(254, 226, 226, 0.95)'
                          : 'rgba(239, 68, 68, 0.20)'
                        : isLight
                        ? '#FFFFFF'
                        : '#FFF9F0',
                    border:
                      m.sender === 'user'
                        ? 'none'
                        : m.sender === 'error'
                        ? '1px solid rgba(239, 68, 68, 0.35)'
                        : isLight
                        ? '1px solid rgba(65, 38, 18, 0.14)'
                        : '1px solid rgba(255, 255, 255, 0.22)',
                    color:
                      m.sender === 'user'
                        ? '#ffffff'
                        : m.sender === 'error'
                        ? '#dc2626'
                        : '#24150b',
                    boxShadow:
                      m.sender === 'user'
                        ? '0 3px 10px rgba(234, 88, 12, 0.25)'
                        : '0 2px 7px rgba(60, 30, 10, 0.06)',
                    fontSize: 10.2,
                    lineHeight: 1.48,
                  }}
                >
                  {m.attachedImageName && (
                    <div
                      style={{
                        fontSize: 8.5,
                        color: m.sender === 'user' ? '#fff' : '#0891b2',
                        marginBottom: 3,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 4,
                      }}
                    >
                      🖼️ {m.attachedImageName}
                    </div>
                  )}

                  {m.sender === 'maki' && (
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 4,
                        marginBottom: 3,
                        fontSize: 8.8,
                        fontWeight: 700,
                        color: '#c2410c',
                      }}
                    >
                      <span>🐾 Maki</span>
                    </div>
                  )}

                  <div className="maki-selectable">{formatMessageHtml(m.text, isLight)}</div>

                  {m.sender === 'maki' && (
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'flex-end',
                        marginTop: 5,
                      }}
                    >
                      <button
                        onClick={() => {
                          navigator.clipboard.writeText(m.text);
                          setCopiedId(m.id);
                          setTimeout(() => setCopiedId(null), 1500);
                        }}
                        style={{
                          fontSize: 8.5,
                          fontWeight: 700,
                          padding: '2.5px 8.5px',
                          borderRadius: 99,
                          border: isLight
                            ? '0.8px solid rgba(234, 88, 12, 0.22)'
                            : 'none',
                          cursor: 'pointer',
                          background:
                            copiedId === m.id
                              ? 'rgba(22, 163, 74, 0.16)'
                              : isLight
                              ? 'rgba(234, 88, 12, 0.09)'
                              : 'rgba(234, 88, 12, 0.14)',
                          color: copiedId === m.id ? '#15803d' : '#c2410c',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 3,
                          transition: 'background 0.15s ease',
                        }}
                        title="Salin seluruh jawaban Maki"
                      >
                        {copiedId === m.id ? '✓ Disalin!' : '📋 Salin Jawaban'}
                      </button>
                    </div>
                  )}
                </div>
              ))
            )}

            {state.isThinking && (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '6px 10px',
                  borderRadius: 10,
                  background: isLight ? '#FFF7ED' : '#FFF9F0',
                  border: '1px solid rgba(249, 115, 22, 0.35)',
                }}
              >
                <span
                  style={{
                    fontSize: 9.5,
                    color: '#c2410c',
                    fontStyle: 'italic',
                    fontWeight: 600,
                  }}
                >
                  🐾 Maki lagi mikir sebentar..
                </span>
                <button
                  onClick={() => void dispatchMaki('cancelGeminiThinking')}
                  style={{
                    fontSize: 8.5,
                    fontWeight: 700,
                    padding: '2.5px 7.5px',
                    borderRadius: 99,
                    background: 'rgba(239, 68, 68, 0.12)',
                    color: '#dc2626',
                    border: '0.8px solid rgba(239, 68, 68, 0.25)',
                    cursor: 'pointer',
                  }}
                  title="Batalkan proses jawaban"
                >
                  ✕ Batal
                </button>
              </div>
            )}
          </div>

          {state.pendingAttachment && (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                padding: '3px 8px',
                borderRadius: 8,
                background: isLight ? 'rgba(236, 254, 255, 0.95)' : 'rgba(6, 182, 212, 0.16)',
                border: isLight
                  ? '0.8px solid rgba(6, 182, 212, 0.32)'
                  : '0.8px solid rgba(34, 211, 238, 0.35)',
                fontSize: 9,
                color: '#0891b2',
              }}
            >
              <img
                src={state.pendingAttachment.dataUrl}
                alt="preview"
                style={{ width: 22, height: 18, objectFit: 'cover', borderRadius: 4 }}
              />
              <span
                style={{
                  flex: 1,
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                  fontWeight: 600,
                }}
              >
                📷 {state.pendingAttachment.name}
              </span>
              <button
                onClick={() => void dispatchMaki('clearGeminiAttachment')}
                style={{
                  color: '#ef4444',
                  fontSize: 10,
                  cursor: 'pointer',
                  background: 'none',
                  border: 'none',
                  fontWeight: 700,
                }}
              >
                ✕
              </button>
            </div>
          )}

          {/* Input Row */}
          <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
            <input
              ref={inputRef}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  sendNow();
                }
              }}
              onPaste={(e) => {
                if (e.clipboardData && e.clipboardData.files.length > 0) {
                  void dispatchMaki('attachScreenshotToGemini');
                }
              }}
              placeholder="Ketik pertanyaan ke Maki..."
              style={{
                flex: 1,
                background: isLight ? '#FFFFFF' : 'rgba(16, 11, 7, 0.85)',
                border: isLight
                  ? '1.2px solid rgba(65, 38, 18, 0.22)'
                  : '1px solid rgba(255, 255, 255, 0.14)',
                borderRadius: 99,
                padding: '6px 12px',
                color: isLight ? '#24150b' : '#f5efe6',
                fontSize: 10.2,
                outline: 'none',
                boxShadow: isLight ? 'inset 0 1px 3px rgba(0, 0, 0, 0.04)' : 'none',
              }}
            />
            <button
              onClick={() => {
                if (state.isThinking) {
                  void dispatchMaki('cancelGeminiThinking');
                } else {
                  sendNow();
                }
              }}
              style={{
                width: 26,
                height: 26,
                borderRadius: 99,
                background: state.isThinking
                  ? '#ef4444'
                  : 'linear-gradient(135deg, #f97316, #ea580c)',
                color: '#ffffff',
                fontWeight: 800,
                fontSize: 11,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                border: 'none',
                boxShadow: '0 2px 7px rgba(234, 88, 12, 0.35)',
                transition: 'transform 0.12s ease',
              }}
              title={state.isThinking ? 'Batalkan (Stop)' : 'Kirim ke Maki'}
            >
              {state.isThinking ? '⏹' : '↑'}
            </button>
          </div>
        </>
      )}
    </div>
  );
};
