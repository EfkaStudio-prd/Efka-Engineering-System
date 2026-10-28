# 01 — Inventaris kondisi mesin (snapshot 28 Oktober 2026)

Semua baris di bawah dihasilkan dari perintah nyata, bukan asumsi. Perintah sumbernya ada di
`scripts/system-doctor.ps1`, jadi dokumen ini bisa di-regenerate kapan pun.

## 1. Toolchain Windows

| Tool | Versi / lokasi | Catatan |
|---|---|---|
| git | 2.55.0.windows.3 — `C:\Program Files\Git\cmd\git.exe` | aktif |
| node | v24.19.0 — `…\WinGet\Packages\OpenJS.NodeJS.LTS_…\node-v24.19.0-win-x64\node.exe` | dipasang lewat winget |
| npm | 11.17.0 | ikut node |
| python | 3.13.15 — `…\Programs\Python\Python313\python.exe` | |
| uv / uvx | 0.12.18 (2026-09-22) | dipakai proyek SketchUp MCP |
| dotnet | `C:\Program Files\dotnet\dotnet.exe` | tersedia |
| java | Zulu 11 JRE | cukup untuk jalan, bukan build |
| pwsh (PowerShell 7) | 7.6.9 — `…\WindowsApps\pwsh.exe` | dipasang 28 Okt via winget (MSIX) |
| jq | 1.8.2 — `…\WinGet\Packages\jqlang.jq_*\jq.exe` | dipasang 28 Okt; PATH efek setelah restart |
| docker / podman (Windows) | tidak ada | sengaja: kontainer hidup di WSL |
| code (CLI) | `…\Qoder IDE\bin\code.cmd` | Qoder |

## 2. Runtime Linux (WSL2 `Ubuntu-24.04`)

| Item | Nilai |
|---|---|
| WSL | 2.7.14.0, kernel 6.18.33.2-2, WSLg 1.0.73.2 |
| node / npm | v22.23.3 / 10.9.9 |
| python3 | 3.12.3 |
| podman | 4.9.3 (rootless, driver overlay, runtime crun) |
| disk di dalam distro | 1007 GB total, 942 GB free (pemakaian 2%) |
| vhdx distro | `%USERPROFILE%\AppData\Local\wsl\{a810ddec-…}\ext4.vhdx` ±14 GB |
| user Linux | `efka` (uid 1000), lingering aktif |

## 3. Qoder plugins (dari `~\.qoder\plugins\installed_plugins_v2.json`)

| Plugin | Versi | Enabled | Scope | Sumber |
|---|---|---|---|---|
| better-harness@qoder-bundler | 0.2.9 | ✅ | user | marketplace |
| computer-use@qoder-bundler | 1.0.1 | ✅ | user | marketplace |
| qoder-create-plugin@qoder-bundler | 0.1.0 | ✅ | user | marketplace |
| security-scan@qoder-bundler | 0.9.4 | ✅ | user | marketplace |
| qoder-context@qoderapp-bundler | 1.0.61 | ✅ (hidden) | user | bawaan aplikasi |

## 4. Skill yang terdeteksi

| Sumber | Jumlah | Nama |
|---|---|---|
| `~\.agents\skills\` (lintas-agen) | 5 | computer-use, find-skills, orca-cli, orchestration, reverse-engineer-anything |
| `~\.qoder\plugins\cache\` (dari plugin) | 7 | better-harness, computer-use, create-plugin, security-scan, qoder-context-knowledge-plan, diagnose-backend-bug, reproduce-frontend-bug |
| `~\.qoder\skills\` (user-level custom) | 0 → **2** | `efka-system-doctor`, `wsl-podman-service` (baru dibuat, perlu restart IDE) |
| built-in IDE | — | create-skill, create-subagent, canvas, qoder-ide-helper, vercel-deploy, … |

Catatan verifikasi: pada sesi ini daftar skill yang dimuat harness **tidak** menampilkan
`security-scan` maupun `qoder-context-knowledge-plan` meskipun filenya ada dan plugin-nya
enabled. Keduanya kemungkinan baru ter-loads setelah restart IDE atau tersambung sebagai
slash command — cek manual dengan mengetik `/` di chat (temuan F-04).

## 5. ekstensi IDE (`~\.qoder\extensions\`)

basedpyright 1.31.6 · clickup 2.2.1 · copilot 1.388.0 + copilot-chat 0.33.5 ·
vscode-pull-request-github 0.122.1 · ms-python.python 2025.16.0 · debugpy 2025.14.0 ·
autopep8 2025.2.0 · python-envs 1.8.0

Belum ada: linter/formatter JS-TS (ESLint/Prettier), Docker/Podman extension, GitLens,
extension tester. Bukan kebutuhan otomatis — lihat peta jalan (`05-roadmap.md`).

## 6. MCP

| Server | Transport | Perintah | Status verifikasi |
|---|---|---|---|
| clickup | stdio via `mcp-remote` | node + `~\.qoder\mcp-bin\node_modules\mcp-remote\dist\proxy.js` → `https://mcp.clickup.com/mcp` | konfigurasi ada; token OAuth ada (umur 4 hari saat audit); **tidak** muncul di folder `mcps` proyek ini → belum terbukti terhubung per proyek (F-02) |
| browser-use | internal Qoder | — | tersedia untuk proyek ini |
| genui | internal Qoder | — | tersedia untuk proyek ini |

## 7. Layanan 9Router (hasil audit + upgrade hari ini)

| Item | Nilai |
|---|---|
| Versi berjalan | 0.5.111, digest `sha256:48f570f9…daf7ccaa` |
| Topologi | podman rootless `--network host`, bind hanya `127.0.0.1:20128`, volume `9router-data` |
| Autostart | Scheduled Task `9Router Autostart` (Ready) + lingering `efka` |
| Idle policy | `vmIdleTimeout=-1`, `instanceIdleTimeout=-1` ada di `.wslconfig` |
| Pin konsisten | runner/installer/checker di `<9Router-Backup>\files` **dan** `Default Project\scripts` = digest live |
| Snapshot terakhir | `~/9router-data-backup-20261027T162852Z.tar.gz` (28 MB, 0600) |

## 8. Temuan (dipakai di `05-roadmap.md`)

| ID | Temuan | Dampak | Status |
|---|---|---|---|
| F-01 | `~\.qoder\skills\` belum ada | tidak ada skill custom milik sendiri | ✅ ditutup hari ini (2 skill dibuat) |
| F-02 | clickup MCP belum terbukti terhubung di sesi proyek | integrasi manajemen tugas mungkin tidak terpakai | ⏸️ di-skip atas permintaan user (28 Okt) |
| F-03 | `mcp.json` menunjuk node ke folder winget versi-spesifik | MCP clickup mati saat node di-upgrade | ⏳ menunggu keputusan (lihat `03-mcp.md`) |
| F-04 | plugin security-scan/qoder-context tidak muncul di daftar skill sesi | kemampuan scan & knowledge-plan tak otomatis terpanggil | ⏳ cek setelah restart IDE |
| F-05 | `<9Router-Backup>` dan `Default Project` bukan repo git | tanpa riwayat perubahan | ✅ ditutup 28 Okt: 3 repo git (hub + 2 proyek), tag `baseline-20261028` |
| F-06 | `~\.qoder\mcp-router.json` memuat API key plaintext di folder profil | risiko bocor kalau profil ikut backup/sync | ✅ **audit 28 Okt**: `OneDrive\Documents` tidak ada, shell folder Documents = `%USERPROFILE%\Documents` (tidak dialihkan ke OneDrive), dan `.qoder`/`.mcp-auth` berada di luar OneDrive → tidak ada sinkronisasi cloud yang membawa kredensial |
| F-07 | Ada beberapa ekosistem agen sekaligus (`~\.agents`, `~\.codex`, `~\.ao`, `~\.cloudbase-mcp`) | konten skill bisa dobel & beda versi | ℹ️ dipantau; belum ada konflik nyata |
| F-08 | Memori AI punya dua entri tumpang tindih soal `.wslconfig` | retrieval noise | ✅ dirapikan hari ini |
