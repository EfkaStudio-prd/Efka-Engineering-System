# 07 — Katalog toolchain (fungsi, cara pakai, upgrade, hapus)

Setiap tool yang terpasang di mesin ini, apa gunanya untuk pekerjaan engineering, dan cara
merawat/mencabutnya. Versi = hasil audit 28 Oktober 2026; verifikasi ulang dengan
`system-doctor.ps1` (bagian `toolchain`).

## 1. Windows — inti

| Tool | Versi | Fungsi di sistem ini | Upgrade | Hapus |
|---|---|---|---|---|
| **git** | 2.55.0 | version control 3 repo + tag `baseline-*`, hook rahasia | `winget upgrade Git.Git` | `winget uninstall Git.Git` |
| **PowerShell 7 (`pwsh`)** | 7.6.9 | shell modern: `??`, `-Parallel`, `ConvertFrom-Json -AsHashtable`, performa lebih baik | `winget upgrade Microsoft.PowerShell` | `winget uninstall Microsoft.PowerShell` |
| **node** | 24.19.0 (LTS, winget) | runtime/CLI JS, `npx` untuk MCP & tool | `winget upgrade OpenJS.NodeJS.LTS` | `winget uninstall OpenJS.NodeJS.LTS` |
| **npm** | 11.17.0 | paket manager JS (ikut node) | `npm install -g npm@latest` | ikut node |
| **python** | 3.13.15 | scripting, alat bantu MCP | `winget upgrade Python.Python.3.13` | `winget uninstall Python.Python.3.13` |
| **uv / uvx** | 0.12.18 | instalasi & eksekusi tool Python cepat (dipakai `sketchup-mcp2`) | `winget upgrade astral-sh.uv` | `winget uninstall astral-sh.uv` |
| **jq** | 1.8.2 | olah JSON di shell: baca `logs\verify-*.json`, inspeksi konfigurasi | `winget upgrade jqlang.jq` | `winget uninstall jqlang.jq` |
| **GitHub CLI (`gh`)** | terpasang | PR/issue/release dari terminal, jalur menuju CI | `winget upgrade GitHub.cli` | `winget uninstall GitHub.cli` |
| **ripgrep (`rg`)** | 15.2.0 | pencarian teks cepat (dipakai tool Grep IDE juga) | `winget upgrade BurntSushi.ripgrep.MSVC` | `winget uninstall BurntSushi.ripgrep.MSVC` |
| **dotnet** | terpasang | build/test .NET bila ada proyek C# | `winget upgrade Microsoft.DotNet.SDK.8` | `winget uninstall Microsoft.DotNet.SDK.8` |
| **Java (Zulu 11 JRE)** | terpasang | menjalankan tool JVM (mis. jadx-gui) | `winget upgrade Alibaba.Zulu11` | `winget uninstall Alibaba.Zulu11` |
| **sqlite3** | via platform-tools | inspeksi DB SQLite langsung | ikut Android platform-tools | ikut paket induk |
| **OpenSSH (`ssh`)** | bawaan Windows | akses remote, git via SSH | Windows Update | — |
| **Qoder CLI (`code`)** | bawaan Qoder | buka folder/berkas dari terminal | ikut Qoder | ikut Qoder |

Catatan pemasangan: `pwsh` dan `jq` dipasang lewat winget pada 28 Okt 2026. `pwsh` terpasang
sebagai paket MSIX sehingga muncul di `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe`, dan
`jq` di `%LOCALAPPDATA%\Microsoft\WinGet\Packages\jqlang.jq_*\jq.exe`. **PATH baru berlaku
setelah shell/IDE di-restart** — karena itu `system-doctor.ps1` mencari keduanya di lokasi
cadangan tersebut, bukan hanya lewat PATH.

## 2. WSL2 `Ubuntu-24.04` (user `efka`)

| Tool | Versi | Fungsi | Upgrade | Hapus |
|---|---|---|---|---|
| **podman** | 4.9.3 (rootless) | menjalankan 9Router sebagai container | `sudo apt update && sudo apt upgrade podman` | `sudo apt remove podman` |
| **node / npm** | 22.23.3 / 10.9.9 | runtime di dalam distro | `sudo npm i -g n && sudo n lts` | — |
| **python3** | 3.12.3 | skrip bantu | `sudo apt upgrade python3` | — |
| **systemd (user)** | — | supervisor `9router-podman.service` + lingering `efka` | bawaan | — |

## 3. Alat yang TIDAK dipasang (dan alasannya)

| Tool | Alasan |
|---|---|
| `make` / `cmake` / `ninja` | belum ada proyek build native; tambahkan saat dibutuhkan |
| `pnpm` / `yarn` | `npm` cukup untuk tooling saat ini; menambah dua package manager = dua sumber lockfile |
| `go` / `rustc` / `cargo` | belum ada target bahasa tersebut |
| Docker Desktop | kontainer sudah dilayani podman rootless di WSL; Docker Desktop menambah VM + lisensi |
| `openssl` (Windows) | sudah tersedia di WSL (`openssl version`), dipakai dari sana |
| linter/formatter (eslint, prettier, ruff) | lebih tepat dipasang **per proyek** supaya versinya terkunci di repo |
| MCP tambahan (Context7, Postgres, GitHub) | menambah proses latar + permukaan kredensial; menunggu kebutuhan nyata (`docs/03-mcp.md` §5) |

## 4. Perintah harian yang memakai tool di atas

```powershell
# kesehatan sistem (git, node, pwsh, jq, podman, 9Router)
powershell -ExecutionPolicy Bypass -File "<hub>\scripts\verify-all.ps1"

# ringkas tren gate terakhir dengan jq (lebih nyaman di pwsh)
jq -r '"\(.timestamp)  ok=\(.ok) warn=\(.warn) fail=\(.fail)"' (Get-ChildItem "<hub>\logs\verify-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 5)

# cari teks cepat lintas repo
rg -n "ImageDigest" <9Router-Backup> %USERPROFILE%\Documents\'Default Project'
```

## 5. Aturan toolchain

1. Semua instalasi lewat `winget` (Windows) atau `apt` (WSL) supaya ada satu jalur upgrade/uninstall.
2. Setelah menambah tool: perbarui tabel di dokumen ini **dan** `docs/01-inventory.md`, lalu
   jalankan gate.
3. Jangan memasang tool yang menduplikasi fungsi yang sudah ada tanpa alasan tertulis.
4. Tool yang butuh kredensial (gh, cloud CLI) tidak disimpan kredensialnya di repo mana pun.
