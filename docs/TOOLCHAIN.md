# TOOLCHAIN — apa yang dipakai, cara upgrade, cara mencabut

EES tidak memasang tool. Tabel ini menjelaskan apa yang **diharapkan ada**, cara merawatnya, dan
apa yang sengaja tidak dipasang. Verifikasi nyata: `scripts/system-doctor.ps1` (bagian `toolchain`).

## 1. Wajib

| Tool | Fungsi | Pasang | Upgrade | Hapus |
|---|---|---|---|---|
| **git** | version control, hook, tag baseline | `winget install Git.Git` / `apt install git` | `winget upgrade Git.Git` | `winget uninstall Git.Git` |
| **PowerShell 7** (`pwsh`, disarankan) | menjalankan skrip lintas platform, `??`, `-Parallel` | lihat docs/INSTALL.md §5 | `winget upgrade Microsoft.PowerShell` | `winget uninstall Microsoft.PowerShell` |

PS 5.1 (Windows) tetap didukung: skrip core sengaja kompatibel agar bisa jalan di Task Scheduler.

## 2. Opsional yang sering dipakai

| Tool | Kapan dipakai | Pasang | Hapus |
|---|---|---|---|
| `node` + `npm` | proyek JS/TS, `npx` untuk tool | `winget install OpenJS.NodeJS.LTS` | `winget uninstall OpenJS.NodeJS.LTS` |
| `python` + `uv` | skrip Python, MCP berbasis Python | `winget install Python.Python.3.13`, `winget install astral-sh.uv` | sesuai paket |
| `jq` | membaca `logs/verify-*.json`, inspeksi JSON | `winget install jqlang.jq` / `apt install jq` | `winget uninstall jqlang.jq` |
| `gh` | PR/issue/release, bahan menuju CI | `winget install GitHub.cli` | `winget uninstall GitHub.cli` |
| `rg` | pencarian teks cepat | `winget install BurntSushi.ripgrep.MSVC` | `winget uninstall …` |
| `podman` | sandbox eksekusi (modul, bukan bagian EES) | `apt install podman` di WSL | `apt remove podman` |

## 3. Sengaja tidak dipasang

| Tool | Alasan |
|---|---|
| linter/formatter global | harus terkunci per proyek (`eslint`, `prettier`, `ruff`) agar versinya tidak berubah diam-diam |
| `pnpm`/`yarn` | dua package manager = dua sumber lockfile; `npm` cukup sampai ada kebutuhan |
| `make`/`cmake`/`ninja` | belum ada build native; tambahkan per proyek |
| Docker Desktop | VM tambahan; kontainer lokal cukup lewat Podman/WSL bila diperlukan |
| MCP tambahan | menambah proses latar + permukaan kredensial; menunggu kebutuhan nyata |

## 4. Menambah tool baru

1. Pastikan tidak menduplikasi fungsi yang sudah ada.
2. Catat di tabel ini: fungsi, pasang, upgrade, hapus.
3. Jalankan `verify-all.ps1`; bila tool itu bagian dari kriteria siap, tambahkan pemeriksaannya.
4. Jangan menaruh kredensial tool di repo; gunakan environment (`secrets.example.env`).
