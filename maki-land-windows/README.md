# 🐾 maki-land untuk Windows 10 & Windows 11

Versi resmi **maki-land** untuk **Windows 10** dan **Windows 11** dengan kesetaraan fitur penuh 100% terhadap versi macOS:
- 🏝️ **Interactive Dynamic Island ("Notch") di Tengah Atas Layar**:
  - Tampilan ringkas (Baterai %, Jam digital, Indikator/Waveform Media, Tray file count, status Mic mute, dan mini maskot Maki).
  - Animasi pelebaran halus saat disentuh kursor (hover) atau diklik.
  - Auto-minimize saat mengklik area di luar Island (atau tekan tombol `Esc`), kecuali jika di-pin 📌.
  - Per-pixel transparency dan transparansi klik-tembus (*click-through*) di luar lengkungan Notch aktif, sehingga jendela atau tombol Windows lain di baliknya tetap dapat diklik secara normal.
  - Mengambang selalu di atas (*Always-on-top*), tersembunyi dari taskbar (`skipTaskbar`), dilengkapi ikon System Tray Windows dengan menu lengkap berbahasa Indonesia.
- 🐾 **Maskot Capybara Mengambang di Desktop (Coucou / Shimeji Style)**:
  - Bebas berjalan-jalan di desktop di atas Taskbar Windows (`desktopRoamEnabled`, dapat dikunci posisinya).
  - Mode permainan interaktif **"Kejar Kursor"** (`🐾`), lempar maskot dengan fisika pantul tepi layar, elus bulu dengan scroll wheel mouse, toel 5x pusing (`dizzy`), dan klik elus hati (`happyPet`).
  - **Animasi Pulang ke Notch**: Maki berjalan ke tepi atas layar dan memanjat masuk ke dalam Notch secara bertahap tanpa pernah hilang mendadak.
  - **Deteksi Hit-Test Presisi & Anti Terangkat Saat Drag File**: Hanya tubuh Maki (dan quick-dock pill) yang menerima klik mouse; area transparan di sekitarnya tembus pandang dan tembus klik 100%. Saat file di-drag mendekati Maki, gerakan jalan otomatis membeku (*freeze*) agar maskot tidak sengaja tergeser saat menerima file drop.
  - **2 Pilihan Model Maskot**:
    1. `🐾 Klasik`: Capybara cokelat berbulu lembut khas Onsen.
    2. `🧸 Boneka`: Maskot boneka krem dengan kaos putih bertuliskan huruf biru **'maki'** (sesuai foto gantungan kunci).
  - Dilengkapi 1–3 tumpuk jeruk yuzu di kepala, headphone DJ hitam matte (`#1B1B1E`), bak rendam Onsen kayu hinoki beruap, dan balon percakapan komik natural.
- 💬 **Integrasi Tanya Maki AI (Google Gemini)**:
  - Tanya jawab AI interaktif di dalam Notch maupun di kartu chat mengambang Desktop.
  - Lampirkan screenshot langsung dari Clipboard (`Win+Shift+S`) atau pilih file gambar/dokumen.
  - Mendukung model Gemini resmi (`gemini-3.5-flash-lite`, `gemini-3.8-flash`, `gemini-4-argon`).
  - Respons cepat dalam Bahasa Indonesia yang santai, cerdas, dan hangat.
- ⚡ **Autorun saat Booting Windows & Reaksi Lock Screen**:
  - Otomatis aktif saat laptop/PC dinyalakan via Registry Windows Startup / Login item setting.
  - **Single-Instance Mutex Lock**: Mencegah aplikasi terbuka dua kali secara bersamaan.
  - Deteksi Lock Screen (`Win+L`) & Sleep: Maki otomatis tidur pulas `zZz 🌙`, dan saat layar dibuka kembali, Maki langsung bangun meregangkan badan dan menyapa: *"Selamat datang kembali! 👋✨"*.

---

## 🗂️ 8 Tab Widget di Dynamic Island

1. **✨ maki-land**:
   - Pemutar musik & media Windows (Sinkronisasi Windows SMTC / tombol media play, pause, next, prev, dan waveform audio bergerak).
   - Kalender & agenda harian (dukungan sinkronisasi Google Calendar / Outlook via URL `.ics` dan input agenda manual).
2. **🐾 Capy**:
   - Kandang & habitat Maki: Level, XP, bar Mood (%), dan Kenyang (%).
   - Beri makan jeruk 🍊, semangka 🍉, sayur 🥬.
   - Atur tumpukan jeruk di kepala (0 s/d 3 jeruk).
   - Mode Onsen air hangat real-time yang sinkron antara Notch dan Desktop.
   - Tombol **Atraksi** (sirkus 3 jeruk, ngoding laptop mini, nyeruput teh matcha, kejar kupu-kupu, tiup gelembung, baca buku, peregangan).
   - Tombol beralih model: **🐾 Klasik** vs **🧸 Boneka Kaos 'maki'**.
   - Tombol **Tanya AI** untuk membuka percakapan Gemini.
3. **📝 Notes**:
   - Scratchpad kilat persisten untuk catatan bebas.
   - Daftar tugas To-Do interaktif (centang selesai, bersihkan yang selesai).
   - Pintasan keyboard `Alt+1..9` untuk toggle tugas, dan `Ctrl+Enter` di scratchpad untuk langsung mengirim baris ke daftar tugas.
4. **🚀 Launch**:
   - Peluncur cepat aplikasi Windows (`.exe`, `.lnk`, folder) dan tautan web favorit.
   - Ambil ikon resmi aplikasi secara otomatis via Windows Shell.
5. **📁 Tray & Studio**:
   - Tempat menampung file dan screenshot: jatuhkan file langsung ke Maki atau ke Notch.
   - Tangkap screenshot instan dari clipboard (`Win+Shift+S`) atau folder `Pictures\Screenshots`.
   - Tarik keluar (*drag-out*) langsung ke Windows Explorer, WhatsApp, Telegram, Slack, atau Figma.
   - Salin file/gambar dengan 1 klik.
   - **Offline Studio**: Gabung beberapa PDF/Gambar jadi 1 PDF, putar PDF (90°/180°/270°), ekstrak/potong halaman PDF, beri watermark teks, konversi format gambar (PNG/JPG), dan kompresi arsip `.zip`.
6. **📊 System**:
   - Pemantau beban CPU Windows (%), penggunaan RAM (GB & %), dan status baterai / charger secara real-time.
7. **📋 Clipboard**:
   - Riwayat salinan teks dan screenshot 24/7 otomatis.
   - Tekan `Alt+1..9` untuk menyalin kembali cuplikan ke clipboard utama seketika.
8. **⏳ Timer**:
   - Timer fokus kerja / Pomodoro dengan pilihan preset 5, 15, 25, 45 menit atau kustom.
   - Peringatan audio dan visual saat waktu habis.

---

## 🚀 Cara Menjalankan & Membangun di Windows

### Syarat Sistem:
- **Windows 10** (versi 1809 ke atas) atau **Windows 11** (64-bit).
- [Node.js](https://nodejs.org) (v18 atau lebih baru) terpasang di komputer.

### Cara Cepat (Jalankan Langsung):
1. Buka folder `maki-land-windows`.
2. Klik dua kali pada file `run-windows.bat`.
3. Aplikasi akan otomatis menginstall dependensi, melakukan build, dan membuka maki-land di desktop Windows Anda!

### Cara Membangun Executable (.exe Installer & Portable):
1. Klik dua kali pada file `build-windows.bat`, atau buka Command Prompt / PowerShell di folder ini lalu ketik:
   ```cmd
   npm install
   npm run build
   npm run dist:win
   ```
2. Hasil build executable akan otomatis tersedia di folder `release/`:
   - `maki-land Setup 1.0.0.exe` (Installer Windows standar dengan shortcut desktop & start menu).
   - `maki-land-Windows-Portable.exe` (Versi portabel tanpa install, langsung jalan dari USB atau folder mana saja).

---

## ⌨️ Pintasan Keyboard (Shortcuts)

- `Esc` : Menutup mode detail Island (auto-minimize ke Notch kecil).
- `Alt + 1..9` : Centang cepat tugas To-Do (pada tab Notes) / salin cepat riwayat (pada tab Clipboard).
- `Ctrl + Enter` : Kirim baris catatan yang sedang aktif di Scratchpad ke daftar To-Do.
- `Win + Shift + S` : Snipping tool Windows bawaan untuk screenshot, lalu klik tombol **Screenshot** atau tombol kamera di Maki untuk langsung memasukkannya ke Tray!
- **Klik Kanan pada Maki di Desktop**: Membuka context menu lengkap berbahasa Indonesia (Tanya AI, Atraksi, Onsen, Tumpuk Jeruk, Model Klasik/Boneka, Kunci Posisi, dan Jalan Pulang).
- **Scroll Wheel pada Tubuh Maki**: Menyisir bulu maskot (*fur brushing*).
- **Klik 2x pada Tubuh Maki**: Menjalankan atraksi acak yang lucu.
- **Tarik & Lempar Maki**: Maskot akan terpental secara elastis dan memantul di tepi layar monitor!

---

## 📄 Lisensi (License)

Proyek ini dilisensikan di bawah **MIT License**. Lihat file [LICENSE](file:///Users/ari/Documents/antigravity/calm-einstein/maki-land-windows/LICENSE) untuk ketentuan lengkapnya. Bebas digunakan, dimodifikasi, dan didistribusikan.

