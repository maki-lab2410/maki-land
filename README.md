# ✨ maki-land

[![Release](https://img.shields.io/badge/release-v1.0.10-orange.svg)](https://github.com/maki-lab2410/maki-land/releases/latest)
[![Platform macOS](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg?logo=apple)](https://github.com/maki-lab2410/maki-land/releases)
[![Platform Windows](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011%20(64--bit)-blue.svg?logo=windows)](https://github.com/maki-lab2410/maki-land/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **Interactive Dynamic Island & Floating Desktop Capybara Companion for macOS and Windows 10/11**

**maki-land** menghadirkan pengalaman Dynamic Island interaktif di bagian tengah atas layar laptop/PC Anda, ditemani oleh maskot Capybara hidup (**"Maki"**) yang ramah, menggemaskan, dan produktif. Anda dapat berinteraksi dengan Maki di notch atau menyeretnya (*drag down*) langsung ke Desktop untuk menemanimu belajar atau bekerja, merawat kebutuhannya, mengelola berkas & tangkapan layar, membersihkan file sampah (*cache*), mengelola catatan & to-do harian, serta berdiskusi langsung dengan AI cerdas (**Google Gemini & Groq**).

---

## 📥 Panduan Instalasi (Installation Guide)

Unduh versi rilis terbaru langsung dari halaman [**GitHub Releases**](https://github.com/maki-lab2410/maki-land/releases/latest).

---

### 🍎 1. Untuk macOS (MacBook, Mac mini, iMac)

Tersedia untuk semua Mac dengan arsitektur **Apple Silicon (M1/M2/M3/M4)** maupun **Intel** (macOS 13.0 Ventura ke atas).

#### Cara Pasang via Disk Image (`.dmg`) — Sangat Direkomendasikan:
1. Buka halaman [**GitHub Releases Terbaru**](https://github.com/maki-lab2410/maki-land/releases/latest) dan unduh file **`makiland-macOS.dmg`**.
2. Klik dua kali file `.dmg` yang telah diunduh untuk membukanya.
3. Seret (drag & drop) ikon **makiland** ke folder **Applications**.
4. Buka folder **Applications** di Mac Anda, lalu klik dua kali pada **makiland**.

#### Mengatasi Peringatan Keamanan Apple Gatekeeper (*Unidentified Developer*):
Karena aplikasi ini dibuat secara independen dan menggunakan penandatanganan kode lokal (*ad-hoc code signing*), macOS mungkin menampilkan dialog:
> *"makiland cannot be opened because it is from an unidentified developer"* atau *"macOS cannot verify that this app is free from malware"*.

**Langkah mudah mengatasinya (cukup 1 kali saja di awal):**
1. Buka folder **Applications** di Finder.
2. **Klik kanan** (atau tahan tombol `Control` lalu klik) pada aplikasi **makiland**.
3. Pilih **Open** dari menu klik kanan.
4. Pada kotak dialog konfirmasi, klik tombol **Open** (atau **Open Anyway**).
5. *Alternatif*: Buka **System Settings** > **Privacy & Security** > gulir ke bawah ke bagian *Security*, lalu klik tombol **Open Anyway**.
6. Aplikasi akan langsung aktif di Hardware Notch atau bar atas layar Anda! ✨

#### Untuk Pengembang (Build Sendiri dari Source Code):
```bash
git clone https://github.com/maki-lab2410/maki-land.git
cd maki-land
chmod +x build_app.sh
./build_app.sh
# Aplikasi hasil build siap dipakai di /Applications/makiland.app
```

---

### 🪟 2. Untuk Windows 10 & Windows 11 (64-bit)

Tersedia dua pilihan paket aplikasi:

#### Pilihan A: Installer Otomatis (`.exe`) — Sangat Direkomendasikan
1. Unduh file **`maki-land.Setup.1.0.10.exe`** dari [**GitHub Releases**](https://github.com/maki-lab2410/maki-land/releases/latest).
2. Klik dua kali file installer tersebut.
3. Ikuti langkah wizard instalasi (installer akan otomatis memasang semua komponen, DLL sistem, serta membuat pintasan resmi di Desktop dan Start Menu).
4. Aplikasi maki-land akan otomatis berjalan di layar atas Anda.

#### Pilihan B: Versi Portable (Tanpa Perlu Install)
1. Unduh file **`maki-land-Windows-Portable.exe`** dari [**GitHub Releases**](https://github.com/maki-lab2410/maki-land/releases/latest).
2. Letakkan file di folder mana pun yang Anda inginkan (misal di folder *Documents* atau *Downloads*).
3. Klik dua kali untuk langsung menjalankannya kapan saja tanpa instalasi sistem.

#### Mengatasi Pesan Error *"The code execution cannot proceed because ffmpeg.dll was not found"*:
Pesan ini muncul di Windows jika file `maki-land.exe` dipindahkan atau dijalankan terpisah dari file pendukungnya:
1. **Penyebab 1: Meng-copy hanya file `maki-land.exe` sendirian ke Desktop**:
   - *Solusi*: Jangan meng-copy filenya langsung. Buatlah **Shortcut**. Klik kanan pada file `maki-land.exe` > pilih **Send to** > **Desktop (create shortcut)**. Atau cukup gunakan installer resmi **`maki-land.Setup.1.0.10.exe`** yang otomatis membuat pintasan yang benar.
2. **Penyebab 2: Membuka file dari dalam file `.zip` tanpa di-ekstrak**:
   - *Solusi*: Klik kanan file `.zip` yang diunduh > pilih **Extract All...** (Ekstrak Semua) ke suatu folder terlebih dahulu sebelum menjalankan aplikasi.

#### Mengatasi Peringatan Windows SmartScreen:
Saat pertama kali membuka installer di Windows, mungkin muncul layar biru bertuliskan:
> *"Windows protected your PC — Microsoft Defender SmartScreen prevented an unrecognized app from starting"*.

**Langkah mengatasinya:**
1. Klik tautan teks bertuliskan **"More info"** (*Informasi selengkapnya*).
2. Klik tombol **"Run anyway"** (*Tetap jalankan*).
3. Aplikasi akan langsung berjalan normal dan aman!

#### Untuk Pengembang (Build Sendiri dari Source Code):
```bash
git clone https://github.com/maki-lab2410/maki-land.git
cd maki-land/maki-land-windows
npm install
npm run build
# Menjalankan langsung versi pengembang:
npm start
# Membuat file installer & portable .exe:
npm run dist:win
```

---

## 🤖 Panduan Setup API AI Gratis (Google Gemini & Groq)

Aplikasi maki-land dilengkapi asisten cerdas **"Tanya Maki"** yang dapat diajak ngobrol, berdiskusi, merangkum gambar/screenshot, dan membantu tugas Anda.

### Cara Mendapatkan API Key Google Gemini (100% Gratis):
1. Buka peramban (browser) dan kunjungi: **[Google AI Studio (aistudio.google.com)](https://aistudio.google.com/)**
2. Masuk menggunakan akun Google Anda, lalu klik tombol **"Create API Key"** (atau *"Get API key"*).
3. Salin (*copy*) kunci API yang diberikan (diawali dengan `AIzaSy...`).
4. Buka aplikasi **maki-land**:
   - Di tab **Capy**, klik tombol **💬 Tanya AI**, lalu klik ikon roda gigi **⚙️ (Pengaturan)**.
   - Atau klik tombol bantuan **`❓`** di samping Notch bar.
   - Tempel (*paste*) API Key Anda dan klik **Simpan Kunci API**.
   - Maki sekarang siap menjawab semua pertanyaanmu! 🎉

> [!TIP]
> **Pilihan Model Alternatif**:
> Selain Google Gemini, Anda juga dapat menggunakan kunci gratis dari **Groq** (*ultra-fast Llama 3*), atau menggunakan **Ollama** lokal yang berjalan 100% offline di komputer Anda tanpa memerlukan kunci API sama sekali!

---

## 🌟 Fitur-Fitur Utama

Antarmuka maki-land dikelompokkan secara terstruktur ke dalam 4 kategori navigasi yang rapi dan mudah diakses:

| Kategori | Tab & Fitur | Kegunaan |
|---|---|---|
| **🏠 Beranda & Maskot** | **✨ maki-land** | Kalender harian (sinkronisasi iCloud/Google Calendar via URL ICS), ucapan salam waktu, dan **sinkronisasi pemutar musik/media real-time** (Spotify, YouTube, Chrome, Edge, VLC, Apple Music di macOS & Windows). |
| | **🐾 Capy Habitat** | Habitat tempat tinggal Maki. Rawat tingkat *Mood* & *Kenyang*, suapi buah (jeruk, semangka, apel), atraksi sirkus jeruk di kepala, kostum, atau klik **💬 Tanya AI** untuk berdiskusi langsung. |
| **📁 Berkas & Media** | **📥 Tray & Studio** | Drop zone cerdas & hub file: simpan sementara screenshot & file, seret keluar (*drag-out*) ke folder/Desktop/aplikasi lain, atau salin file langsung (`Ctrl+V` / `⌘V`). Dilengkapi **PDF Studio** (gabung, putar, pecah PDF), mini audio player, dan tombol ringkas tanya AI. |
| | **🪞 Cermin Kamera (Mirror)** | Fitur cermin webcam cepat langsung di layar: dilengkapi lampu penerang *ring light*, pembalik horizontal (*flip mirror*), dan pengambilan foto/selfie instan yang langsung otomatis tersimpan ke Tray & clipboard. |
| | **🎙️ Rekam Suara (Voice)** | Memo suara cepat dengan waveform audio interaktif dan timer durasi. Rekaman langsung diekspor dan siap dipakai di Tray. |
| **📝 Catatan & Fokus** | **📝 Notes & To-Do** | Kolom ganda: **Scratchpad** kilat (tekan `⌘↩` / `Ctrl+Enter` untuk kirim baris ke To-Do) dan daftar **To‑Do** interaktif dengan pintasan centang tugas cepat (`⌥1` s/d `⌥9`). Mode `⤢ Penuh` tersedia untuk melihat catatan panjang. |
| | **⏱️ Timer Fokus** | Pengatur waktu fokus Pomodoro dengan preset waktu dan alarm visual saat sesi selesai. |
| | **📋 Clipboard** | Riwayat papan klip (*clipboard history*) otomatis yang mengingat teks dan cuplikan gambar yang baru saja disalin. |
| **⚙️ Alat & Sistem** | **📊 System & Clean** | Monitor metrik CPU, RAM, Baterai, dan pembersih sampah aman (**Maki Safe Cache Cleaner**) untuk membersihkan cache developer (Xcode, Homebrew, Gradle), browser, dan berkas sementara. |
| | **🪟 Launch** | Dermaga pintasan cepat (*Quick Launcher*) untuk membuka aplikasi favorit, folder kerja, maupun website penting dengan satu klik. |

---

## 🐾 Sahabat Desktop (Desktop Mascot Companion)

* **Lepas ke Desktop**: Seret (drag) Maki ke bawah keluar dari Notch, atau klik menu *"Lepas Maki ke Desktop"*. Maki akan berjalan bebas, santai, dan beraktivitas di atas taskbar/layar Anda ala Coucou!
* **Interaksi Klik Kanan**: Klik kanan pada tubuh Maki di Desktop untuk membuka menu interaktif (beri makan, ajak sirkus 3 jeruk, ngoding bareng, nyeruput teh, main kejar kursor, berendam air panas Onsen, atau bersihkan cache).
* **Panggil Pulang**: Klik kanan Maki > pilih *"Jalan Pulang ke Notch"*, atau klik tombol rumah di Notch bar.

---

## 🔄 Pembaruan Otomatis (Auto-Updater)

Aplikasi secara otomatis memeriksa versi terbaru dari GitHub setiap 4 jam:
* Jika ada rilis baru, badge **`✨ Update`** akan muncul di bar Notch dan menu konteks desktop.
* Anda juga dapat memeriksa secara manual kapan saja dengan klik tombol **`🔄 Periksa Pembaruan...`** pada menu klik kanan Maki atau melalui tab **System**.

---

## 📄 Lisensi (License)

Proyek ini dilisensikan di bawah **MIT License**. Lihat file [LICENSE](LICENSE) untuk detail lengkap. Bebas digunakan, dipelajari, dimodifikasi, dan didistribusikan.