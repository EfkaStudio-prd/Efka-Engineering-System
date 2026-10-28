# 03 — MCP (Model Context Protocol): kondisi, verifikasi, penambahan

## 1. Kondisi sekarang

Konfigurasi user: `%USERPROFILE%\.qoder\mcp.json`.

| Server | Transport | Perintah nyata | Catatan |
|---|---|---|---|
| `clickup` | stdio | `node.exe` (folder winget NodeJS.LTS v24.19.0) + `~\.qoder\mcp-bin\node_modules\mcp-remote\dist\proxy.js https://mcp.clickup.com/mcp`, env `MCP_REMOTE_CONFIG_DIR=%USERPROFILE%\.mcp-auth` | satu-satunya MCP eksternal |
| `browser-use` | internal IDE | — | muncul di folder `mcps` proyek; tool browser tersedia untuk agen |
| `genui` | internal IDE | — | sama |

Bukti pendukung saat audit: paket `mcp-remote` ada, dan `~\.mcp-auth` berisi
`*_tokens.json` (umur 4 hari) → OAuth clickup pernah berhasil.
Tetapi folder `mcps` untuk proyek ini hanya memuat `browser-use` dan `genui`, jadi
**koneksi clickup per-sesi belum terbukti** (temuan F-02).

## 2. Cara memverifikasi (urut, tanpa menebak)

1. Settings → **MCP** → lihat status `clickup` (connected / error) dan daftar tool-nya.
2. Dari terminal, cek proses router MCP hidup dan port-nya (jangan tempel isinya ke dokumen
   mana pun — file `mcp-router.json` memuat API key):
   ```powershell
   Get-Content "$env:USERPROFILE\.qoder\mcp-router.json" | ConvertFrom-Json | Select-Object pid,baseUrl,startedAt
   ```
3. `system-doctor.ps1` bagian `mcp` (sudah berjalan) → memberi status command path, umur
   token, dan peringatan jalur rapuh.
4. Uji nyata di chat: minta agen memanggil satu tool clickup (misal daftar list). Kalau gagal,
   error IDE lebih informatif daripada menebak.

## 3. Masalah nyata yang perlu diputuskan

### F-03 — jalur node versi-spesifik

`mcp.json` menunjuk ke
`…\WinGet\Packages\OpenJS.NodeJS.LTS_…\node-v24.19.0-win-x64\node.exe`.
Folder ini berubah nama saat Node LTS naik versi → MCP clickup mati diam-diam.

Opsi (menunggu persetujuan, karena mengubah konfigurasi global):

| Opsi | Kelebihan | Risiko |
|---|---|---|
| A. Pakai `"command": "node"` | tahan upgrade, sederhana | bergantung PATH saat IDE diluncurkan dari shell berbeda |
| B. Simpan symlink `node.cmd` tetap di `~\.qoder\mcp-bin\` | stabil & eksplisit | perlu maintenance symlink |
| C. Biarkan, tapi tambahkan ke daftar periksa doctor | nol perubahan | tetap rapuh |

Rekomendasi: **A**, dengan fallback C tetap tinggal di doctor.

### F-06 — rahasia di folder profil

`~\.qoder\mcp-router.json` (API key) dan `~\.mcp-auth\*_tokens.json` adalah kredensial.
Pastikan keduanya tidak masuk: backup cloud otomatis, sinkronisasi OneDrive folder user,
atau repo mana pun. Kalau `%USERPROFILE%\OneDrive` aktif, tambahkan pengecualian untuk
`.qoder` dan `.mcp-auth`.

## 4. Menambah MCP server dengan benar

Gunakan skill **`qoder-ide-helper`** ("tambahkan MCP …") supaya penulisannya ke konfigurasi
user mengikuti format IDE, atau manual lewat Settings → MCP → Add. Pola yang valid:

```json
{
  "mcpServers": {
    "example-local": {
      "type": "stdio",
      "command": "uvx",
      "args": ["example-mcp"],
      "env": {}
    },
    "example-remote": {
      "type": "stdio",
      "command": "node",
      "args": ["C:\\Users\\Pongo\\.qoder\\mcp-bin\\node_modules\\mcp-remote\\dist\\proxy.js", "https://example.com/mcp"],
      "env": { "MCP_REMOTE_CONFIG_DIR": "C:\\Users\\Pongo\\.mcp-auth" }
    }
  }
}
```

Setelah menyimpan: restart / reload MCP, verifikasi tool muncul, lalu tambah baris di `01-inventory.md`.

## 5. Kandidat yang relevan (hasil riset, belum dipasang)

Riset 2026 konsisten menyebut beberapa MCP yang paling sering dipakai untuk kerja rekayasa:
GitHub, Playwright/browser automation, Filesystem, Context7 (dokumentasi library), Postgres/DB,
Atlassian/Linear (ticket). Sumber: totalum.app, ayautomate.com, gamut.so, agentmail.to
(diakses 28 Okt 2026; daftar populer, bukan rekomendasi tanpa kebutuhan).

Pemetaan ke kondisi mesin ini:

| Kebutuhan | Sudah tercukupi oleh | Perlu MCP baru? |
|---|---|---|
| Browser & verifikasi UI | MCP `browser-use` internal + skill `computer-use` | tidak |
| Manipulasi file/repo | tool IDE + git CLI | tidak |
| Kode GitHub (PR/issue) | ekstensi `github.vscode-pull-request-github`, `gh` CLI belum ada | mungkin (GitHub MCP) — nilai tambah kecil |
| Dokumentasi library terkini | agen bisa web search/fetch | Context7 berguna kalau sering SDK besar |
| Basis data aplikasi | — | Postgres MCP kalau mulai ada DB lokal |
| Manajemen tugas | clickup MCP + ekstensi clickup | sudah ada, tinggal verifikasi |

Keputusan sengaja ditahan: menambah MCP berarti menambah permukaan kredensial & proses latar
belakang. Dilakukan satu per satu, sesuai kebutuhan proyek nyata berikutnya.
