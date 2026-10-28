# 06 — Pondasi produksi: enam pilar dan wujud nyatanya

Tujuan: hasil engineering yang **konsisten**, bukan bergantung ingatan. Enam pilar di bawah
adalah syarat minimum; setiap pilar harus punya artefak yang bisa dijalankan, bukan hanya niat.

| # | Pilar | Wujud nyata di mesin ini | Cara membuktikan |
|---|---|---|---|
| 1 | **Satu sumber kebenaran** | `<hub>\` + `compare-locations.ps1` untuk salinan kembar | `verify-all.ps1` bagian `drift` |
| 2 | **Gerbang verifikasi** | `system-doctor.ps1` (lingkungan) + `verify-all.ps1` (semua seksi, exit code) | jalankan, lihat `OK/WARN/FAIL` |
| 3 | **Version control** | git di hub, `9Router_Backup`, `Default Project`; tag `baseline-*` | `git -C <repo> log --oneline` |
| 4 | **Higiene rahasia** | `scan-secrets.ps1` + `.gitignore` per repo | `verify-all.ps1` bagian `secrets` |
| 5 | **Observabilitas** | `logs\verify-<ts>.json` dari setiap gate + Scheduled Task `Efka System Doctor` | lihat `logs\` dan Task Scheduler |
| 6 | **Keseragaman proyek baru** | `New-EfkaProject.ps1` (README, AGENTS.md, .gitignore, .gitattributes, check.ps1, commit+tag) | scaffold percobaan, lihat `.git` & tag |

## 1. Satu sumber kebenaran

- Folder hub menyimpan **status** (inventaris, roadmap) dan **tooling**; repo proyek menyimpan
  kode; memori agen menyimpan **pelajaran**. Tidak ada topik yang ditulis dua kali.
- Salinan ganda hanya diizinkan bila ada pemeriksa: model 9Router (`files\` ↔ `Default Project\scripts\`)
  dijaga `compare-locations.ps1`, dan `verify-all.ps1` menjalankannya setiap kali.

## 2. Gerbang verifikasi

`system-doctor.ps1` menjawab "apakah mesin siap", `verify-all.ps1` menjawab "apakah sistem
secara keseluruhan masih sah". Keduanya read-only dan mengembalikan exit code:

```powershell
powershell -ExecutionPolicy Bypass -File "<hub>\scripts\verify-all.ps1"
```

Seksi yang diperiksa: `doctor`, `secrets`, `drift`, `gateway`, `repos`. Definisi selesai untuk
pekerjaan apa pun di mesin ini: **gate hijau** (boleh ada WARN yang sudah dipahami, tidak boleh
ada FAIL).

## 3. Version control

Tiga repo, masing-masing dengan `baseline-20261028`:

| Repo | Isi | Catatan |
|---|---|---|
| `<hub>` | hub: dokumen + skrip | `core.autocrlf=true` di mesin ini, jadi `.gitattributes` memaksa `*.sh eol=lf` agar skrip WSL tidak rusak saat checkout |
| `<9Router-Backup>` | installer/updater/validator 9Router | `*.zip` dan `wslconfig*.backup` di-ignore |
| `Default Project` | OpenCode/SketchUp MCP + sumber kanonis 9Router | artefak biner tetap dilacak; `.rbz` ditandai binary |

Aturan: commit kecil dan bermakna; tag `baseline-YYYYMMDD` setiap kali kondisi terbukti sehat;
tidak ada `git push` tanpa diminta (tidak ada remote yang dikonfigurasi).

## 4. Higiene rahasia

`scan-secrets.ps1` sengaja konservatif — hanya pola yang hampir pasti rahasia:

- nama file: `mcp-router.json`, `*_tokens.json`, `.env*`, `initial-password.env`,
  `id_rsa|ed25519|ecdsa`, `*.pfx|p12|pem|key`, `_netrc|.npmrc|.pypirc|credentials`
- isi: blok private key, field JSON `apiKey|token|secret|password` dengan nilai panjang,
  AWS access key, Bearer token, dan assignment `password=…` dengan nilai nyata
  (baris berisi `example|contoh|placeholder|<…>` diabaikan)
- nama kunci ber-prefix juga tertangkap (`db_password=`, `my_token=`, `client_secret=`) lewat
  regex `[A-Za-z0-9_.-]*(password|passwd|secret|token|api_?key|access_?key|private_?key|client_?secret)\s*[=:]`

Penjaganya bukan sekadar skrip manual: satu implementasi hook hidup di
`<hub>\.githooks\pre-commit` dan tiap repo diarahkan lewat
`git config core.hooksPath "C:/Efka Engineering System/.githooks"`. Commit yang mengandung
kredensial ditolak — terbukti dengan uji `db_password=…`: commit exit 1, jumlah commit tidak
bertambah. Bypass yang disadari: `git commit --no-verify`. `verify-all.ps1` ikut memeriksa
`core.hooksPath` tiap repo supaya guard tidak pernah lepas tanpa ketahuan.

Kredensial yang memang harus ada di mesin ini tetap di luar repo:
`%USERPROFILE%\.qoder\mcp-router.json`, `%USERPROFILE%\.mcp-auth\*_tokens.json`,
`~/.config/9router/initial-password.env`, isi volume `9router-data`.

## 5. Observabilitas

Setiap eksekusi `verify-all.ps1` menulis `logs\verify-<timestamp>.json` (mesin-baca) dan `.txt`
(manusia-baca), jadi tren FAIL/WARN terlihat tanpa harus ingat menjalankan manual. Log di-ignore
oleh git; yang dilacak hanya `logs\.gitkeep`.

Dua Scheduled Task menutup dua kebutuhan berbeda:

| Task | Kapan | Cakupan | Alasan |
|---|---|---|---|
| `Efka System Doctor` | harian 08:00 | doctor + secrets + drift + repos (`-SkipWsl`) | tidak pernah membangunkan WSL hanya untuk memeriksa |
| `Efka System Verify (logon)` | 3 menit setelah logon | **semua lima seksi**, termasuk gateway | saat itu WSL sudah dinyalakan `9Router Autostart`, jadi gateway benar-benar terperiksa |

Keduanya berjalan sebagai user yang sama dengan sesi interaktif, tanpa hak admin, dan menulis log
ke folder yang sama. Retensi log: `verify-all.ps1` menyimpan **60 run terakhir** (≈1 bulan pada
2 run/hari) lalu memangkas yang lebih tua, jadi folder `logs\` tidak tumbuh tanpa batas.
Gate lengkap yang hijau (28 Okt 2026, doctor 37 pemeriksaan):
`doctor OK · secrets OK · drift OK · gateway OK · repos OK`.

Membaca tren:

```powershell
Get-ChildItem '<hub>\logs\verify-*.json' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
  ForEach-Object { (Get-Content $_.FullName -Raw | ConvertFrom-Json) | Select-Object timestamp, ok, warn, fail }
```

## 6. Keseragaman proyek baru

```powershell
powershell -ExecutionPolicy Bypass -File "<hub>\scripts\New-EfkaProject.ps1" `
  -Path 'C:\Projects\my-api' -Name 'My API' -Kind node
```

Hasil: `README.md` (dengan definisi selesai), `AGENTS.md` dari template (diisi placeholder
nama proyek), `.gitignore` sesuai jenis, `.gitattributes` (EOL aman), `docs\`, `check.ps1`
(secrets + build/test sesuai `-Kind`), git repo dengan commit awal dan tag `baseline-YYYYMMDD`.
`-DryRun` mencetak rencana tanpa menulis apa pun.

## Yang tetap belum maksimal (jujur)

| Kekurangan | Dampak | Jalan keluar |
|---|---|---|
| ~~`pwsh` (PowerShell 7) tidak ada~~ | **selesai 28 Okt**: pwsh 7.6.9 terpasang; skrip sistem tetap kompatibel PS 5.1 agar aman di sesi Task Scheduler | `winget upgrade Microsoft.PowerShell` |
| ~~`jq` tidak ada~~ | **selesai 28 Okt**: jq 1.8.2 terpasang; dipakai membaca `logs\verify-*.json` | `winget upgrade jqlang.jq` |
| Tanpa linter/formatter JS-Python di level mesin | gaya kode belum ditegakkan otomatis | tambahkan per proyek (`eslint`, `prettier`, `ruff`) saat proyeknya ada |
| Tidak ada CI remote | gerbang hanya berjalan lokal | tambah workflow saat ada remote GitHub (`gh` sudah terpasang) |
| Tanpa coverage/test wajib | "selesai" masih bergantung pada test yang ditulis | `check.ps1` per proyek sudah menyediakan kaitnya |
| ~~OneDrive aktif di profil user~~ | **audit 28 Okt**: `OneDrive\Documents` tidak ada dan folder Documents tetap `%USERPROFILE%\Documents`, jadi `.qoder`, `.mcp-auth`, dan repo proyek tidak ikut sinkronisasi cloud | ulangi audit ini kalau suatu saat 'Known Folder Move' diaktifkan |
| Gate dijalankan di dalam sandbox IDE | proses anak (nested `powershell`) bisa diblokir sehingga seksi tampak kosong | jalankan dari terminal biasa atau lewat Scheduled Task; sejak 28 Okt gate menandainya `WARN`, bukan `FAIL` palsu |
