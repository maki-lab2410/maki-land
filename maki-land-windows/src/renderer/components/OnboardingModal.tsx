import React, { useState } from 'react';
import { dispatchMaki } from '../bridge';
import { SharedAppState } from '../../shared/types';

export const OnboardingModal: React.FC<{ state: SharedAppState }> = ({ state }) => {
  const [currentStep, setCurrentStep] = useState(1);
  const totalSteps = 4;

  const complete = () => {
    void dispatchMaki('closeOnboarding');
  };

  const openGoogleStudio = () => {
    void dispatchMaki('openExternalUrl', { url: 'https://aistudio.google.com/app/apikey' });
  };

  const openGroqConsole = () => {
    void dispatchMaki('openExternalUrl', { url: 'https://console.groq.com/keys' });
  };

  const openKeySettings = () => {
    void dispatchMaki('toggleGeminiSettings');
    complete();
  };

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 999,
        background: '#0a0a0c',
        borderRadius: 22,
        padding: '12px 18px',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        color: '#fff',
        boxShadow: '0 8px 32px rgba(0,0,0,0.85)',
      }}
    >
      {/* Top Header Row with Close button */}
      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <button
          onClick={complete}
          title="Tutup Panduan"
          style={{
            background: 'none',
            border: 'none',
            color: 'rgba(255,255,255,0.45)',
            fontSize: 14,
            cursor: 'pointer',
            padding: 2,
          }}
        >
          ✕
        </button>
      </div>

      {/* Main Slide Content */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center' }}>
        {currentStep === 1 && (
          <div style={{ display: 'flex', gap: 16, alignItems: 'center', width: '100%' }}>
            <div style={{ width: 85, textAlign: 'center', flexShrink: 0 }}>
              <div
                style={{
                  width: 58,
                  height: 58,
                  borderRadius: 99,
                  background: 'rgba(249,115,22,0.18)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 28,
                  margin: '0 auto 6px',
                }}
              >
                🏝️
              </div>
              <div style={{ fontSize: 11, fontWeight: 800, color: '#f97316' }}>maki-land</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, fontWeight: 800, marginBottom: 4 }}>
                Selamat Datang di maki-land Windows! 👋
              </div>
              <div style={{ fontSize: 9.5, color: 'rgba(255,255,255,0.8)', lineHeight: 1.5, marginBottom: 6 }}>
                Dynamic Island interaktif & maskot capybara hidup di layar komputermu. Gratis & open-source.
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 9.2, color: 'rgba(255,255,255,0.88)' }}>
                <div>✨ <b>Notch Atas Layar</b>: Hover atau klik notch di tengah atas monitor untuk membuka menu cepat.</div>
                <div>🎵 <b>Musik & Kalender</b>: Kendalikan media player & pantau jadwal harianmu.</div>
                <div>📝 <b>Notes, To-Do & Tray</b>: Catatan kilat, daftar tugas terorganisir, dan drag & drop file.</div>
              </div>
            </div>
          </div>
        )}

        {currentStep === 2 && (
          <div style={{ display: 'flex', gap: 16, alignItems: 'center', width: '100%' }}>
            <div style={{ width: 85, textAlign: 'center', flexShrink: 0 }}>
              <div
                style={{
                  width: 58,
                  height: 58,
                  borderRadius: 99,
                  background: 'rgba(34,197,94,0.18)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 28,
                  margin: '0 auto 6px',
                }}
              >
                🐾
              </div>
              <div style={{ fontSize: 11, fontWeight: 800, color: '#4ade80' }}>Maki Temanmu</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, fontWeight: 800, marginBottom: 4 }}>
                Ajak Maki Bermain di Desktop Windows! 🐾
              </div>
              <div style={{ fontSize: 9.5, color: 'rgba(255,255,255,0.8)', lineHeight: 1.5, marginBottom: 6 }}>
                Tarik Maki keluar dari notch ke desktop. Dekatkan kursor ke tubuh Maki untuk memunculkan Quick Dock:
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 3.5, fontSize: 9.2, color: 'rgba(255,255,255,0.88)' }}>
                <div>💬 <b>Tanya Maki</b>: Asisten AI pintar serbaguna siap menjawab apa pun.</div>
                <div>📸 <b>Ambil Screenshot</b>: Tangkap layar langsung masuk ke Tray.</div>
                <div>🍊 <b>Kasih Jeruk & Onsen</b>: Tumpuk jeruk di kepala Maki atau ajak berendam air hangat ♨️.</div>
                <div>🧹 <b>Sapu Cache Aman (Maki Clean)</b>: Pindahkan sampah Windows ke Recycle Bin dengan 1 klik!</div>
              </div>
            </div>
          </div>
        )}

        {currentStep === 3 && (
          <div style={{ display: 'flex', gap: 16, alignItems: 'center', width: '100%' }}>
            <div style={{ width: 85, textAlign: 'center', flexShrink: 0 }}>
              <div
                style={{
                  width: 58,
                  height: 58,
                  borderRadius: 99,
                  background: 'rgba(6,182,212,0.18)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 28,
                  margin: '0 auto 6px',
                }}
              >
                🔑
              </div>
              <div style={{ fontSize: 11, fontWeight: 800, color: '#06b6d4' }}>Setup AI Cepat</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 3 }}>
                <span style={{ fontSize: 13, fontWeight: 800 }}>Cara Setup Kunci API AI (100% Gratis!) 🌿</span>
                <span style={{ fontSize: 8, background: 'rgba(34,197,94,0.22)', color: '#4ade80', padding: '1px 5px', borderRadius: 4, fontWeight: 700 }}>
                  Mudah
                </span>
              </div>
              <div style={{ fontSize: 9.3, color: 'rgba(255,255,255,0.78)', marginBottom: 5 }}>
                Tanya Maki ditenagai AI pintar. Dapatkan kunci gratis dalam 3 langkah mudah:
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 3, fontSize: 9, color: 'rgba(255,255,255,0.9)' }}>
                <div><b>1.</b> Klik tombol <b>Buka Google AI Studio</b> (login dengan akun Google-mu)</div>
                <div><b>2.</b> Klik tombol biru <b>Create API Key</b> (Buat Kunci API)</div>
                <div><b>3.</b> Salin kuncinya, lalu tempel di Pengaturan API Key Maki</div>
              </div>
              <div style={{ display: 'flex', gap: 8, marginTop: 7 }}>
                <button
                  onClick={openGoogleStudio}
                  style={{
                    padding: '4px 10px',
                    borderRadius: 99,
                    background: '#2563eb',
                    border: 'none',
                    color: '#fff',
                    fontSize: 9.5,
                    fontWeight: 700,
                    cursor: 'pointer',
                  }}
                >
                  🌐 Buka Google AI Studio (Gratis)
                </button>
                <button
                  onClick={openKeySettings}
                  style={{
                    padding: '4px 10px',
                    borderRadius: 99,
                    background: 'rgba(255,255,255,0.12)',
                    border: 'none',
                    color: '#fff',
                    fontSize: 9.5,
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  🔑 Atur Kunci di Maki
                </button>
              </div>
              <div style={{ fontSize: 8, color: 'rgba(255,255,255,0.5)', marginTop: 4 }}>
                💡 Bisa juga pakai Groq (console.groq.com) atau Ollama (100% lokal offline tanpa API Key).
              </div>
            </div>
          </div>
        )}

        {currentStep === 4 && (
          <div style={{ display: 'flex', gap: 16, alignItems: 'center', width: '100%' }}>
            <div style={{ width: 85, textAlign: 'center', flexShrink: 0 }}>
              <div
                style={{
                  width: 58,
                  height: 58,
                  borderRadius: 99,
                  background: 'rgba(234,179,8,0.20)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 28,
                  margin: '0 auto 6px',
                }}
              >
                ✨
              </div>
              <div style={{ fontSize: 11, fontWeight: 800, color: '#eab308' }}>Semua Siap!</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, fontWeight: 800, marginBottom: 4 }}>
                Kamu Siap Menggunakan maki-land! 🚀
              </div>
              <div style={{ fontSize: 9.5, color: 'rgba(255,255,255,0.8)', lineHeight: 1.5, marginBottom: 6 }}>
                Tips praktis untuk hari-harimu bersama Maki:
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 3.5, fontSize: 9.2, color: 'rgba(255,255,255,0.88)' }}>
                <div>📌 <b>Pin Notch</b>: Tekan ikon pin agar Dynamic Island selalu terbuka di layar.</div>
                <div>📸 <b>Screenshot Cepat</b>: Ambil screenshot dengan Win+Shift+S lalu paste ke chat Maki.</div>
                <div>📁 <b>Drag File</b>: Tarik file gambar/PDF ke notch untuk kompres atau konversi otomatis.</div>
                <div>❓ <b>Buka Panduan Lagi</b>: Klik kanan tubuh Maki di desktop kapan saja.</div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Bottom Footer: Stepper Dots & Action Buttons */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingTop: 6 }}>
        {/* Step dots */}
        <div style={{ display: 'flex', gap: 5 }}>
          {Array.from({ length: totalSteps }).map((_, i) => (
            <div
              key={i}
              style={{
                width: currentStep === i + 1 ? 8 : 6,
                height: currentStep === i + 1 ? 8 : 6,
                borderRadius: 99,
                background: currentStep === i + 1 ? '#f97316' : 'rgba(255,255,255,0.25)',
                transition: 'all 0.2s ease',
              }}
            />
          ))}
        </div>

        {/* Buttons */}
        <div style={{ display: 'flex', gap: 8 }}>
          {currentStep > 1 && (
            <button
              onClick={() => setCurrentStep((s) => s - 1)}
              style={{
                padding: '4px 10px',
                borderRadius: 99,
                background: 'rgba(255,255,255,0.08)',
                border: 'none',
                color: 'rgba(255,255,255,0.85)',
                fontSize: 9.5,
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Kembali
            </button>
          )}

          <button
            onClick={() => {
              if (currentStep < totalSteps) setCurrentStep((s) => s + 1);
              else complete();
            }}
            style={{
              padding: '5px 14px',
              borderRadius: 99,
              background: 'linear-gradient(135deg, #ea580c, #f97316)',
              border: 'none',
              color: '#fff',
              fontSize: 10,
              fontWeight: 700,
              cursor: 'pointer',
              boxShadow: '0 2px 8px rgba(249,115,22,0.4)',
            }}
          >
            {currentStep < totalSteps ? 'Lanjut ➔' : 'Mulai Sekarang! 🚀'}
          </button>
        </div>
      </div>
    </div>
  );
};
