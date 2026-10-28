# 05 — Peta jalan kesiapan produksi

Urut prioritas. Yang **P0 sudah dikerjakan hari ini** ada buktinya; P1 ke bawah butuh
persetujuan karena menyentuh konfigurasi global, jaringan, atau data.

## P0 — selesai 28 Oktober 2026

| # | Pekerjaan | Bukti |
|---|---|---|
| 1 | 9Router dipulihkan & di-upgrade ke 0.5.111 tanpa kehilangan provider | `verify-9router.ps1` lolos; `providerConnections=71`, `apiKeys=3`, SQLite `integrity=ok`; dashboard 200 |
| 2 | Autostart Windows + idle policy WSL dipulihkan | Scheduled Task `9Router Autostart` state Ready; VM tetap `Running` setelah 150 dtk idle |
| 3 | Tooling operasional 9Router: updater, validator, sinkroniser | `<9Router-Backup>\{update-9router.ps1, verify-9router.ps1, sync-default-project.ps1, compare-locations.ps1}` |
| 4 | Drift pin image di dua lokasi skrip ditutup | 11 file dobel = identik; semua pin = digest live (`compare-locations.ps1`) |
| 5 | Hub "Efka Engineering System" dibuat + dokumentasi per komponen | folder ini |
| 6 | `system-doctor.ps1` (read-only, exit code) berjalan | 33→41 check, FAIL/WARN/OK/INFO |
| 7 | 2 skill custom user-level ditulis | `~\.qoder\skills\{efka-system-doctor, wsl-podman-service}\SKILL.md` |
| 8 | Memori AI dirapikan (tumpang tindih `.wslconfig` dipecah sesuai topik) | lihat `04-memory-knowledge.md` §3 |

## P1 — butuh keputusanmu (menunggu "ya/ok/tidak" per butir)

| # | Butir | Perintah / tindakan | Kenapa penting | Risiko |
|---|---|---|---|---|
| 1 | ~~Restart Qoder IDE, konfirmasi 2 skill muncul~~ | **selesai**: kedua skill sudah muncul di daftar skill sesi | — | — |
| 2 | ~~`git init` untuk 2 proyek~~ | **selesai**: 3 repo (hub + 2 proyek) dengan `.gitignore`/`.gitattributes` dan tag `baseline-20261028` | rollback berbasis riwayat | — |
| 3 | ~~Perbaiki jalur node di `mcp.json` (F-03)~~ | **ditunda**: clickup di-skip atas permintaan user | — | dievaluasi lagi saat clickup dipakai |
| 4 | ~~Verifikasi koneksi MCP clickup (F-02)~~ | **ditunda** bersama #3 | — | — |
| 5 | Kecualikan `~\.qoder\` & `~\.mcp-auth\` dari sinkronisasi cloud (F-06) | cek keberadaan OneDrive/backup | API key & token OAuth jangan keluar mesin | none |
| 6 | Bersihkan artefak lama: snapshot parsial `9router-data-backup-20261027T162647Z.tar.gz` + image `0.5.86`/`latest` lama (±1,5 GB) | `wsl -d Ubuntu-24.04 -- podman rmi …` | kapasitas & kejelasan | hapus permanen; jangan sebelum upgrade stabil 1 minggu |
| 7 | Plugin-kan folder hub (`/create-plugin`) supaya portable lintas mesin | `/create-plugin` dari `<hub>` | satu langkah untuk mesin kedua | sedang; bisa jadi duplikasi kalau tidak disiplin satu sumber |

## P2 — setelah P1 (butuh kasus nyata dulu)

1. **Doctor terjadwal**: Scheduled Task harian `system-doctor.ps1 -Json` → tulis ke log di
   `hub\logs\`, dan FAIL memicu notifikasi. Baru berguna setelah F-03/F-05 beres.
2. **Template AGENTS.md** untuk tiap proyek baru (sudah disiapkan `templates\AGENTS.project.md`);
   isi untuk kedua proyek yang ada.
3. **MCP tambahan** hanya saat dibutuhkan: Context7 (dokumentasi SDK), Postgres (kalau ada DB
   lokal), GitHub (kalau `gh` CLI tidak cukup). See `03-mcp.md` §5.
4. **Skill khusus domain** kalau muncul pekerjaan berulang: mis. `sketchup-mcp-verify`
   (proyek SketchUp), `release-checklist`. Pembuatan: `/create-skill`.
5. **Gerbang kualitas per repo**: satu skrip `check.ps1`/`make verify` di tiap proyek supaya
   agen punya cara objektif memutuskan "selesai".
6. **Audit harness periodik**: `/better-harness` tiap ~5 sesi panjang untuk menangkap pola
   kerja berulang agen.

## Definisi "Efka Engineering System v1 siap produksi"

- [x] Satu folder kanonis berisi status, SOP, dan tooling — tanpa duplikat
- [x] Gerbang pemeriksaan otomatis yang bisa dibaca mesin (`exit code`)
- [x] Layanan infrastruktur (9Router) sehat, autostart, dan pin-nya konsisten di semua salinan
- [x] Pengetahuan agen tertata: lesson di memori, kondisi di dokumen, kontrak di repo
- [x] Tidak ada FAIL tersisa di `system-doctor.ps1` (0 FAIL per 28 Okt)
- [ ] Setiap proyek punya version control dan `AGENTS.md`
- [ ] Kredensial tidak pernah muncul di dokumen/backup keluar mesin
- [x] Skill custom terlihat & terpanggil di sesi chat (`efka-system-doctor`, `wsl-podman-service`)

## Yang sengaja TIDAK dilakukan

- Menginstal plugin/skill/MCP dari marketplace/jaringan tanpa persetujuan (butuh unduhan +
  mengubah konfigurasi global; dan belum ada kebutuhan terbukti).
- Membuat salinan cermin folder hub di tempat lain — itu persis pola yang menyebabkan drift.
- Menulis token/API key ke dokumen mana pun, termasuk contoh JSON (path saja, tanpa isi).

## Catatan eksekusi — pondasi produksi (28 Okt 2026, sesi lanjutan)

Permintaan: skip MCP clickup, bangun pondasinya, laporkan apa yang belum maksimal.

| Artefak | Fungsi |
|---|---|
| `scripts/verify-all.ps1` | gerbang tunggal: `doctor` + `secrets` + `drift` + `gateway` + `repos`, menulis log JSON/TXT |
| `scripts/scan-secrets.ps1` | pemindai kredensial (nama file & isi), dipakai gate dan oleh `check.ps1` proyek baru |
| `scripts/New-EfkaProject.ps1` | scaffold proyek: README, AGENTS.md, `.gitignore`, `.gitattributes`, `check.ps1`, commit + tag |
| `docs/06-foundations.md` | enam pilar pondasi + daftar kekurangan yang masih jujur |
| git | 3 repo (hub, `9Router_Backup`, `Default Project`) + tag `baseline-20261028` |
| `logs/` | riwayat hasil gate, di-ignore git |

Tidak dikerjakan, dengan alasan: perbaikan `mcp.json` (clickup di-skip user), `pwsh`/`jq`/linter
(butuh unduhan jaringan, menunggu persetujuan), pengecualian OneDrive (butuh keputusan user,
tidak diubah diam-diam).
