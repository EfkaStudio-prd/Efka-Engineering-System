# 04 — Memori & Knowledge Base agen AI

Ada **tiga** tempat pengetahuan di mesin ini, dan mencampuradukkannya adalah sumber hasil
engineering yang tidak konsisten.

| Tempat | Isi | Siapa yang baca | Umur |
|---|---|---|---|
| **Qoder Memory** (`~\.qoder\memories\`) | preferensi user, konvensi proyek, pengalaman/kesalahan, keputusan | otomatis di setiap sesi (ringkasan topik → detail saat diretrieve) | lintas sesi, permanen sampai dirapikan |
| **Knowledge base repositori** (`qoder-knowledge`, index per proyek) | modul: batas file, arsitektur, tech stack, konvensi kode | otomatis saat mengerjakan repo itu | diperbarui IDE dari kode nyata |
| **Dokumen di `<hub>`** | status mesin, katalog tooling, SOP, peta jalan | dibaca saat tugas global / audit | dikelola manusia, sengaja |

Aturan pemisahan: **lesson → memory**, **fakta kondisi → dokumen**, **kontrak kode → repo**.
Jangan tulis hal yang sama tiga kali; cukup saling rujuk dengan nama.

## 1. Kategori memori yang ada (dan kapan dipakai)

| Kategori | Bentuk isi yang benar |
|---|---|
| `project_environment_configuration` | satu fakta konfigurasi per memori, kalimat deklaratif (mis. "gateway 9Router ada di `localhost:20128`, host `localhost` bukan `127.0.0.1`") |
| `project_introduction` / `project_tech_stack` / `project_build_configuration` | seperti di atas, per aspek proyek |
| `development_code_specification` / `_practice_` / `_test_` / `_comment_` | konvensi yang bisa dites, bukan selera |
| `tool_experience` / `mcp_experience` / `skill_experience` / `task_experience` | pelajaran **umum**: lepaskan nama file/proyek masih valid. Format: Usage Scenario / Usage Method / Notes |
| `common_pitfalls_experience` | **boleh** spesifik mesin: jenis bug, akar masalah, pola perbaikan, pelajaran yang bisa dipakai + batas keberlakuannya |
| `important_decision_experience` | keputusan + alasan trade-off + alternatif yang ditolak + kapan keputusan ini kedaluwarsa |
| `task_summary_experience` | snapshot eksekusi; badan aslinya jangan dihapus, koreksi ditambahkan di akhir |
| `user_*` | hanya dari pernyataan eksplisit user; satu memori aktif per kategori |

Yang **tidak** boleh masuk memori: kredensial/token/password, perintah berbahaya
(`rm`, `--force`, format), fakta sementara yang segera basi, hal yang bisa disimpulkan dari
membaca kode, dan preferensi bahasa respons (itu diatur di Settings IDE).

## 2. Isi memori mesin ini sekarang (28 Okt 2026, setelah perapian)

| Judul | Kategori | Inti |
|---|---|---|
| 9Router WSL/Podman Environment Setup | project_environment_configuration | letak layanan, kebutuhan `vmIdleTimeout`/`instanceIdleTimeout`, Scheduled Task autostart |
| WSL VM auto-shutdown due to missing idle-timeout in .wslconfig | common_pitfalls_experience | pola diagnostik **umum**: aplikasi WSL "hilang" padahal `.wslconfig` ketimpa; merge, jangan overwrite |
| 9Router image pin drift between WSL runner and duplicated install scripts | common_pitfalls_experience | spesifik mesin: digest live vs pin di dua lokasi skrip; cara cek & cara sinkron |
| Capturing wsl.exe output from redirected PowerShell yields mojibake | tool_experience | output UTF-16 `wsl.exe` rusak saat PowerShell dialihkan; lewati lewat file |
| Snapshotting rootless Podman volume data requires podman unshare tar streaming | tool_experience | file volume dimiliki UID hasil pemetaan; pakai `podman unshare tar -f -` |
| Efka Engineering System hub location, doctor gate, and no-silent-install policy | important_decision_experience | lokasi kanonis, gerbang `system-doctor.ps1`, larangan instal diam-diam |

## 3. Perapian yang dilakukan hari ini

Sebelumnya ada **dua** memori yang tumpang tindih membahas `.wslconfig` hilang
(F-08). Yang generik dibiarkan utuh; yang satu lagi ditulis ulang menjadi murni soal
**drift pin image 9Router** (judul, kata kunci, skenario pemakaian ikut diubah) sehingga
tiap memori kembali membahas satu topik. Tidak ada informasi yang dibuang.

## 4. Kebiasaan yang membuat hasil konsisten

1. **Sebelum mengubah modul**: retrieve memori & knowledge modul itu dulu; kalau tidak ada,
   buat dari fakta yang sudah diverifikasi — bukan dari asumsi.
2. **Sesuai verifikasi**: memori bisa basi. Sebelum memakai, cek cepat ke kode/konfigurasi;
   kalau bertentangan dengan kenyataan, perbaiki memorinya (atau hapus) dan nyatakan ke user.
3. **Update > buat baru**: memori serupa yang sudah ada diperbarui, bukan diduplikasi.
4. **Setiap keputusan arsitektur** yang mahal untuk dibalik → `important_decision_experience`,
   termasuk kondisi kedaluwarsanya.
5. **Kesalahan yang berulang** → tulis sebagai pitfall dengan pola: apa yang salah → dampaknya
   → bagaimana menghindarinya.
6. **Kondisi sistem** (versi tool, plugin terpasang) tidak disimpan di memori, tapi di
   `01-inventory.md` yang bisa di-regenerate oleh doctor — memori cukup menunjuk ke sana.
