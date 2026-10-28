# Efka Engineering System

Lapisan kontrol untuk pekerjaan engineering di mesin mana pun: memeriksa kesiapan, menegakkan
invarian, menyediakan kontrak kerja, dan mencatat bukti. **Berdiri sendiri** — semua sistem lain
(gateway model, sandbox, eval, agen) adalah *modul* yang diverifikasi, bukan diinstal.

```
Windows   : irm https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.ps1 | iex
Linux/WSL : curl -fsSL https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.sh | bash
```

Mulai dari **[docs/INSTALL.md](docs/INSTALL.md)**, lalu **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## 1. Apa yang ada di dalam

| Komponen | Fungsi | Bukti kerja |
|---|---|---|
| `core/scripts/system-doctor.ps1` | kesiapan toolchain, surface agen, MCP, repo, file kredensial, disk | exit code + tabel per item |
| `core/scripts/verify-all.ps1` | gate: doctor + secrets + setiap `adapters/*/verify.ps1` | `logs/verify-<ts>.json`, retensi 60 run |
| `core/scripts/scan-secrets.ps1` | pemindai kredensial (nama file + isi) | exit 1 saat menemukan |
| `core/scripts/validate-review.ps1` | menegakkan kontrak review | exit 1 + daftar pelanggaran |
| `core/scripts/New-EfkaProject.ps1` | proyek baru: AGENTS.md, `.gitignore`, `.gitattributes`, `check.ps1`, commit + tag | repo langsung patuh baseline |
| `core/githooks/pre-commit` | penjaga rahasia untuk setiap commit | commit berisi kredensial ditolak |
| `core/templates/` | `TASK_CONTRACT`, `EVIDENCE_RECEIPT`, `HANDOFF`, `review-output.schema.json`, `AGENTS.project.md` | dipakai sebelum/selama/sesudah kerja |
| `skills/efka-system-doctor` | skill agen untuk menjalankan & menafsirkan gate | dipasang ke surface agen yang terdeteksi |
| `docs/` | INSTALL, ARCHITECTURE, MODULES, GATES, CONTRACTS, MEMORY, TOOLCHAIN, SCORE, GEMS | rujukan kerja |

## 2. Prinsip

1. **Berdiri sendiri.** `core/` tidak tahu nama host, path pengguna, atau produk tertentu.
   Yang khusus mesin hidup di `adapters/` dan tidak ikut tercopy ke mesin lain.
2. **Tidak ada kredensial di repo.** Semua dari environment (`secrets.example.env`).
3. **Gerbang, bukan opini.** "Selesai" = gate hijau + tes teramati, bukan kalimat "done".
4. **Fail-closed.** Kapabilitas tak didukung = `BLOCKED`, bukan fallback diam-diam.
5. **Satu sumber kebenaran.** Instalasi dihasilkan dari repo ini; tidak ada salinan manual.
6. **Tanpa bukti bukan temuan.** Finding review wajib menyertakan kutipan/output.

## 3. Struktur

```
install.ps1 / install.sh     bootstrapper 1-klik (Windows / Unix)
manifest.json · VERSION      daftar komponen, invarian, versi
core/
  scripts/                   doctor · gate · secret-scan · validate-review · scaffold
  githooks/                  secret guard
  templates/                 kontrak kerja + schema review + AGENTS proyek
skills/                      skill agen yang ikut dipasang
docs/                        INSTALL · ARCHITECTURE · MODULES · GATES · CONTRACTS · MEMORY · TOOLCHAIN · SCORE · GEMS
adapters/                    lapisan khusus host/modul (tidak tercopy, tidak wajib)
```

## 4. Modul, bukan bagian sistem

EES **tidak** memasang atau mengonfigurasi gateway model, sandbox, atau eval harness. Cara
memverifikasinya ada di [docs/MODULES.md](docs/MODULES.md): satu folder `adapters/<nama>/verify.ps1`
di mesinmu, otomatis dijalankan gate. Status modul muncul sebagai `adapter:<nama>`, terpisah dari
status EES.

## 5. Perintah yang sering dipakai

```powershell
# gate lengkap
powershell -ExecutionPolicy Bypass -File "$HOME\Efka Engineering System\scripts\verify-all.ps1"

# proyek baru yang langsung patuh baseline
powershell -ExecutionPolicy Bypass -File "$HOME\Efka Engineering System\scripts\New-EfkaProject.ps1" `
  -Path 'C:\Projects\my-api' -Name 'My API' -Kind node

# validasi keluaran review sebelum merge
Get-Content .\review.json -Raw | powershell -File "$HOME\Efka Engineering System\scripts\validate-review.ps1"
```

## 6. Status dan batas

- Skor **manajemen sistem 85/100**, **kematangan harness engineering ±52/100** (naik dari 44
  setelah kontrak kerja + validator review ada; belum ditegakkan otomatis). Rincian:
  [docs/SCORE.md](docs/SCORE.md).
- Belum ada: eksekusi terisolasi, pengumpulan receipt otomatis, reviewer independen, eval matrix, CI.
- Lisensi belum ditetapkan. Tambahkan `LICENSE` sebelum dipakai pihak lain.
