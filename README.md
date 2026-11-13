# PixelAquarium

Akuarium pixel art 16-bit yang berenang di desktop: ikan, kawanan ikan kecil, ubur-ubur, kepiting,
peti harta, serta hiu dan penyu yang sesekali lewat. Ada siklus siang, senja, dan malam.

Seluruh gambar ada di satu file, `aquarium.html` (canvas 128×80 piksel, tanpa dependensi).
Aplikasi macOS (`main.swift`) dan Windows (`windows/`) hanya pembungkus yang menampilkannya di jendela melayang.

## Fitur
- Seret untuk memindahkan, klik 2× untuk memberi makan ikan, klik kanan untuk menu
- Ukuran 2×, 3×, atau 4×
- Siklus siang-malam: waktu nyata, dipercepat (1 hari = 4 menit), siang terus, malam terus
- Tombol untuk memanggil hiu atau penyu
- Mac: pilih selalu di atas jendela atau di belakang jendela

## macOS
Butuh Xcode Command Line Tools.

```
./build.sh
open ~/Applications/PixelAquarium.app
```

Ikon 🐠 muncul di menu bar. Aplikasi tidak ditandatangani resmi, jadi saat pertama dibuka mungkin perlu klik kanan > Open.

## Windows
Butuh Node.js. Versi Windows belum diuji di perangkat Windows, jadi laporkan jika ada masalah.

```
cd windows
npm install
npm start          # jalankan
npm run build      # buat .exe portable di windows/dist
```

Menu ada di ikon system tray. Mode di belakang jendela belum tersedia di Windows.

## Struktur
- `aquarium.html`: seluruh animasi dan gambar
- `main.swift`, `build.sh`: pembungkus macOS
- `windows/`: pembungkus Windows (Electron)
