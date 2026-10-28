# INSTALL — satu perintah, lalu apa

## 1. Pasang

**Windows (PowerShell 5.1+ atau 7):**

```powershell
irm https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.ps1 | iex
```

**Linux / WSL / macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.sh | bash
```

**Dari clone (disarankan kalau kamu akan mengubah repo):**

```powershell
git clone https://github.com/EfkaStudio-prd/Efka-Engineering-System
cd Efka-Engineering-System
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun   # lihat rencana dulu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## 2. Pilihan installer

| Opsi | Default | Arti |
|---|---|---|
| `-Target` | `%USERPROFILE%\Efka Engineering System` (`$HOME/Efka Engineering System`) | lokasi instalasi; `EFKA_TARGET` untuk versi bash |
| `-Profile` | `core` | hanya `core` yang diuji saat ini; profil lain disediakan untuk bundle tambahan di masa depan |
| `-WithTasks` | mati | mendaftarkan Scheduled Task harian `Efka System Doctor` |
| `-DryRun` | mati | cetak rencana, tidak menulis apa pun |

Installer **idempotent**: menjalankan ulang akan memperbarui `scripts/`, `templates/`,
`githooks/`, `docs/`, dan skill; folder `adapters/` dan `logs/` milikmu tidak disentuh.

## 3. Yang dilakukan installer

1. Menyalin core ke target (scripts, templates, githooks, docs, manifest, VERSION).
2. Menyalin `skills/` ke setiap surface agen yang **terdeteksi**: `~/.qoder/skills`,
   `~/.config/opencode/skills`, `~/.claude/skills`, `~/.codex/skills`.
3. `git init` (bila belum) + `core.hooksPath` → `githooks/` (penjaga rahasia aktif).
4. Opsional: Scheduled Task harian (`-WithTasks`).
5. Menjalankan `system-doctor.ps1` dan mencetak langkah berikutnya.

**Tidak** dilakukan installer: memasang tool (node/python/uv/pwsh/jq), menulis nilai
kredensial, mengubah konfigurasi global agen selain menyalin skill, atau menjalankan `git push`.

## 4. Setelah instalasi

```powershell
# gerbang lengkap: doctor + rahasia + adapter host
powershell -ExecutionPolicy Bypass -File "$HOME\Efka Engineering System\scripts\verify-all.ps1"

# proyek baru yang langsung patuh baseline
powershell -ExecutionPolicy Bypass -File "$HOME\Efka Engineering System\scripts\New-EfkaProject.ps1" `
  -Path 'C:\Projects\my-api' -Name 'My API' -Kind node
```

Hasil gate tersimpan di `logs/verify-<timestamp>.json` (retensi 60 run). Exit `1` = ada FAIL.

### 4b. Kontrak kerja (opsional, tetapi disarankan)

Template siap pakai di `core/templates/`:

| Kebutuhan | File | Penegak |
|---|---|---|
| Sebelum mulai kerja | `TASK_CONTRACT.md` | review manusia |
| Bukti per aksi | `EVIDENCE_RECEIPT.md` | review |
| Sebelum merge | `review-output.schema.json` | `scripts/validate-review.ps1` |
| Pindah sesi/agen | `HANDOFF.md` | manusia |

```powershell
# validasi keluaran review (exit 1 = kontrak dilanggar)
Get-Content .\review.json -Raw | powershell -File "$HOME\Efka Engineering System\scripts\validate-review.ps1"
```

## 5. Kredensial

Jangan menaruh nilai di file mana pun. Set sebagai environment variable:

```powershell
# PowerShell profile
$env:EFKA_9ROUTER_KEY = '...'
# bash/zsh
export EFKA_9ROUTER_KEY='...'
```

Daftar variabel ada di `secrets.example.env`. Bila ada yang terlanjur ter-commit:
**rotasi key tersebut** (menganggapnya bocor), lalu bersihkan riwayat dengan `git filter-repo`.

## 6. Upgrade

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1     # dari clone terbaru
# atau
irm https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.ps1 | iex
```

Skill, script, dan template ikut diperbarui. `VERSION` dan `manifest.json` menunjukkan
apa yang terpasang.

## 7. Uninstall

```powershell
Remove-Item -Recurse -Force "$HOME\Efka Engineering System"
# skill (opsional)
Remove-Item -Recurse -Force "$HOME\.qoder\skills\efka-system-doctor"
# task (opsional)
Unregister-ScheduledTask -TaskName 'Efka System Doctor' -Confirm:$false
```

Tidak ada perubahan lain di sistem: installer tidak menulis registry, tidak memasang service,
dan tidak mengubah PATH.

## 8. Troubleshooting

| Gejala | Penyebab | Tindakan |
|---|---|---|
| `child process could not start` di gate | proses anak diblokir sandbox IDE | jalankan gate dari terminal biasa |
| `doctor: FAIL 1` pada `git` | git belum terpasang | pasang git, ulangi installer |
| skill tidak muncul di agen | agen perlu restart | restart Qoder/OpenCode, lalu ketik `/` |
| `git commit` ditolak `secret-guard` | ada pola kredensial di working tree | hapus/ignore file itu; `--no-verify` hanya bila yakin |
| installer tidak menemukan `core/` | dijalankan lewat pipe tanpa file | biarkan installer mengunduh sendiri (`irm ... | iex`) |
