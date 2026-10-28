# Efka Engineering System

Sistem engineering global yang bisa dipakai siapa saja, dipasang dengan **satu perintah**,
dan menjaga dirinya sendiri lewat gerbang verifikasi. Isinya: tooling pemeriksa, penjaga
rahasia, scaffolder proyek, template, dan handbook — bukan aplikasi.

```
Windows   : irm https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.ps1 | iex
Linux/WSL : curl -fsSL https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.sh | bash
```

Sesudah instalasi: `scripts/verify-all.ps1` memberi satu verdict atas lingkungan, rahasia,
dan repo. Detail: **[docs/INSTALL.md](docs/INSTALL.md)**.

---

## Untuk siapa

- Kamu memakai lebih dari satu agen (Qoder, OpenCode, Claude Code, Codex) dan ingin **satu**
  sumber aturan, skill, dan gerbang kualitas.
- Kamu ingin tahu apakah mesinmu benar-benar siap, bukan menebak.
- Kamu ingin setiap pekerjaan punya bukti: exit code, log, hook, tag — bukan "sepertinya sudah".

## Apa yang dipasang

| Komponen | Fungsi | Bukti kerja |
|---|---|---|
| `scripts/system-doctor.ps1` | kesiapan toolchain, surface agen, MCP, repo, file kredensial, disk | exit code + tabel per item |
| `scripts/verify-all.ps1` | gerbang produksi: doctor + secrets + adapter host | `logs/verify-<ts>.json`, retensi 60 run |
| `scripts/scan-secrets.ps1` | pemindai kredensial (nama file + isi) | menolak dengan exit 1 |
| `scripts/New-EfkaProject.ps1` | proyek baru: AGENTS.md, `.gitignore`, `.gitattributes`, `check.ps1`, commit + tag | repo langsung patuh baseline |
| `githooks/pre-commit` | penjaga rahasia untuk setiap commit | commit berisi kredensial ditolak |
| `skills/` | `efka-system-doctor`, `wsl-podman-service` | dipasang ke semua surface agen yang terdeteksi |
| `templates/AGENTS.project.md` | kerangka konteks proyek | dipakai scaffolder |
| `docs/` | handbook: inventaris, katalog skill, MCP, memori, roadmap, fondasi, toolchain | dibaca manusia/agen |
| `opencode/` | lane OpenCode (agen, skill, command, config) | dipasang dengan `-Profile full` |

## Prinsip yang tidak dinegosiasikan

1. **Tidak ada kredensial di repo.** Konfigurasi membaca `EFKA_9ROUTER_KEY`, `FIRECRAWL_API_KEY`,
   dst. dari environment; contoh ada di `secrets.example.env`.
2. **Satu sumber kebenaran.** Repo ini sumbernya; mesin meng-*install* dari sini, bukan menyalin manual.
3. **Gerbang, bukan opini.** "Selesai" berarti gate hijau dengan log, bukan kalimat "done".
4. **Fail-closed.** Kapabilitas yang tidak didukung = `BLOCKED`, bukan fallback diam-diam.
5. **Tidak ada instal diam-diam.** Menambah tool/MCP/plugin = keputusan eksplisit + dicatat.

## Struktur

```
install.ps1 / install.sh     bootstrapper 1-klik (Windows / Unix)
manifest.json                daftar komponen + invarian + versi
VERSION                      2.0.0
core/
  scripts/                   doctor, gate, secret-scan, scaffold (portable)
  githooks/                  secret guard
  templates/                 AGENTS.project.md
skills/                      skill agen yang ikut dipasang
docs/                        handbook + INSTALL/GEMS/SCORE + lane OpenCode
opencode/                    konfigurasi lane OpenCode (eksperimental)
adapters/                    lapisan khusus host (tidak ikut tercopy ke mesin lain)
```

## Status dan batas

- Skor **manajemen sistem 85%**, skor **kematangan harness engineering 44%** — rincian,
  bobot, dan jalannya ke 80% ada di [docs/SCORE.md](docs/SCORE.md).
- Handbok host-spesifik (9Router/WSL, Podman, sinkronisasi dua folder) tetap ada di `docs/`
  sebagai contoh nyata; jangan dianggap bagian wajib dari core.
- Lane OpenCode berasal dari build Agustus 2026 (lihat [docs/ENGINEERING.md](docs/ENGINEERING.md));
  statusnya **eksperimental** dan tidak dijalankan oleh gate.

## Berkontribusi / mengubah

```bash
git clone https://github.com/EfkaStudio-prd/Efka-Engineering-System
cd Efka-Engineering-System
pwsh -File install.ps1 -DryRun     # lihat rencana
```

Setiap perubahan wajib: `scan-secrets` bersih, `verify-all` hijau, dan satu baris di
`manifest.json` bila menambah komponen.

Lisensi: belum ditetapkan. Tambahkan `LICENSE` sebelum dipakai pihak lain.
