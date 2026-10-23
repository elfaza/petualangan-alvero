# Petualangan Alvero

Game edukasi berhitung untuk anak-anak. Bantu Alvero menyiapkan bekal piknik,
memberi makan kelinci, membuat pai, mengisi gerobak buah, dan menghias pesta.
Setiap misi memakai benda yang berbeda. Jawab soal berhitung, kumpulkan benda
yang diminta, lalu lanjutkan petualangannya di peta.

## Menjalankan di Chrome

Flutter SDK pada komputer ini tersimpan di
`/Users/mohammedfaza/Documents/Codex/.tools/flutter`. Tambahkan SDK dan cache
dependensinya ke environment terminal, lalu jalankan dari folder project:

```sh
export PATH="/Users/mohammedfaza/Documents/Codex/.tools/flutter/bin:$PATH"
export PUB_CACHE="/Users/mohammedfaza/Documents/Codex/.tools/petualangan-kiko-pub-cache"
flutter pub get
flutter run -d chrome
```

Jika Flutter tidak dapat meluncurkan Chrome secara langsung, jalankan server
web lalu buka alamatnya di Chrome:

```sh
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5174
```

Buka `http://127.0.0.1:5174`.

Untuk membuat versi web siap rilis:

```sh
flutter build web
```

Project ini mencakup konfigurasi Flutter untuk Android, iOS, web, macOS,
Windows, dan Linux.
