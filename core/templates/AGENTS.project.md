# AGENTS.md — <nama proyek>

Kerangka untuk proyek baru. Salin ke `<repo>\AGENTS.md`, isi semua bagian; hapus bagian yang
tidak relevan, jangan biarkan kosong. Target: agen (atau manusia) bisa beroperasi tanpa menggali.

## 1. Tujuan & status

- Tujuan satu kalimat: …
- Status: `prototype | aktif | produksi`
- Definisi "selesai" untuk pekerjaan di sini: <bukti apa yang harus ada>

## 2. Perintah

| Aktivitas | Perintah |
|---|---|
| Setup | `…` |
| Jalankan lokal | `…` |
| Uji | `…` |
| Build / rilis | `…` |
| Verifikasi menyeluruh | `…` (harus lolos sebelum dianggap selesai) |

## 3. Peta & arsitektur

- Direktori penting + isi singkat (max 8 baris).
- Batas modul: siapa memanggil siapa; tunjuk konfigurasi kanonis (jangan salin).
- Layanan/dependensi eksternal: port, cara restart, lokasi data.

## 4. Invarian yang tidak boleh dilanggar

- <contoh: gateway hanya bind 127.0.0.1; jangan pernah commit isi volume/backup kredensial>
- <contoh: versi image selalu dipin digest, dan pin harus sama di semua salinan skrip>

## 5. Konvensi

- Bahasa/komit/gaya kode: <link ke spesifikasi atau 3 bullet cukup>
- Penamaan file & cabang: …
- Format log/diagnostik yang dipakai agen: …

## 6. Jebakan yang diketahui

| Symptom | Akar masalah | Tindakan |
|---|---|---|
| … | … | … |

## 7. Larangan (do-nots)

- Jangan <perubahan global/destruktif> tanpa persetujuan.
- Jangan menyalin file konfigurasi ke lokasi kedua — pakai satu sumber + sinkronisasi.
- Jangan menulis token/kredensial ke dokumen atau commit.

## 8. Referensi

- Dokumen sistem: `<hub>\README.md`
- Pemeriksaan mesin: `<hub>\scripts\system-doctor.ps1`
