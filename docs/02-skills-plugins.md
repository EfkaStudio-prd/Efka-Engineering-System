# 02 — Skill & Plugin: katalog, cara pakai, cara menambah

Referensi resmi: `docs.qoder.com/extensions/skills` dan `docs.qoder.com/extensions/plugins`.

## 1. Konsep yang perlu dibedakan

| Konsep | Isi | Lokasi | Kelola di |
|---|---|---|---|
| **Skill** | folder berisi `SKILL.md` (frontmatter `name`, `description`) + file bantu | user: `~\.qoder\skills\{nama}\` · proyek: `{repo}\.qoder\skills\{nama}\` · lintas-agen: `~\.agents\skills\` | Settings → Skills; nama sama → proyek menang |
| **Plugin** | paket Skill + MCP + Agent + Command + Rules + Hooks sekaligus | cache: `~\.qoder\plugins\cache\{bundler}\{plugin}\` | Settings → Plugins → Marketplace / Manage |
| **Subagent** | agen khusus yang di-dispatch agen utama | `~\.qoder\` (dibuat via `/create-subagent`) | Settings → Agents |

Plugin tidak bisa dipasang sebagian komponennya; menolak satu komponen berarti menonaktifkan
seluruh plugin.

## 2. Yang sudah terpasang di mesin ini (28 Okt 2026)

| Plugin / Skill | Fungsi nyata | Kapan dipakai | Cara memanggil |
|---|---|---|---|
| `better-harness` 0.2.9 | audit harness agen: kerja berulang, aset agen, hasil sesi, rencana perbaikan | setelah beberapa sesi panjang, atau saat agen terasa "lupa"/berulang | hanya lewat slash command `/better-harness` |
| `computer-use` 1.0.1 | kontrol GUI aplikasi desktop yang terlihat (klik/ketik/screenshot) | hanya kalau jalur programatik (shell/filesystem/CLI) tidak bisa | `/computer-use` atau minta eksplisit |
| `qoder-create-plugin` 0.1.0 | mengubah SKILL.md, folder lokal, atau link marketplace menjadi plugin Qoder | saat sebuah skill ingin dibagikan sebagai plugin | `/create-plugin` |
| `security-scan` 0.9.4 | scan keamanan cloud L2/L3, hasil async, gate sebelum push/PR | sebelum push, buka PR, release, deploy | `/security-scan` (belum muncul di daftar skill sesi ini → lihat F-04) |
| `qoder-context` 1.0.61 (hidden) | knowledge plan untuk konteks proyek | otomatis oleh IDE | tidak untuk dipanggil manual |
| `find-skills` | cari & pasang skill komunitas (skills.sh / GitHub) | "adakah skill untuk X?" | `/find-skills` |
| `reverse-engineer-anything` | RE target biner/Electron/firmware dengan evidence runtime | hanya tugas reverse engineering | otomatis saat target bukan source repo |
| `orca-cli`, `orchestration` | worktree/konteks/terminal Orca, koordinasi antar agen | kalau alur kerja pakai Orca | otomatis sesuai kata kunci |
| built-in: `create-skill`, `create-subagent`, `canvas`, `qoder-ide-helper`, `vercel-deploy` | bikin skill/subagen baru, artifact `.canvas.tsx`, tanya-jawab & konfigurasi IDE (MCP/Skill/Subagent), deploy Vercel | masing-masing sesuai permintaan | `/create-skill`, `/qoder-ide-helper`, dll |

## 3. Skill custom baru milik sistem ini (user-level)

Dibuat hari ini di `~\.qoder\skills\`:

| Skill | Fungsi | Pemicu alami |
|---|---|---|
| `efka-system-doctor` | menjalankan `<hub>\scripts\system-doctor.ps1`, menafsirkan FAIL/WARN, memberi aksi perbaikan konkret | "cek kesiapan sistem", "apa yang rusak di laptop ini", "audit tooling" |
| `wsl-podman-service` | prosedur aman merawat layanan rootless Podman di WSL (status, snapshot volume dengan `podman unshare`, ganti pin digest, restart, validasi) | "update/restart 9Router", "snapshot volume podman", "gateway WSL tidak bisa diakses" |

**Cara mengaktifkan:** restart Qoder IDE, lalu ketik `/` di chat — keduanya harus muncul.
Kalau tidak muncul, cek `~\.qoder\skills\{nama}\SKILL.md` (frontmatter wajib `name` +
`description`) dan pastikan tidak ada skill nama sama di level proyek.

**Cara menghapus:** hapus foldernya; tidak ada efek ke plugin bawaan.

## 4. Menambah skill baru (urutan yang disarankan)

1. **Cari dulu** — `/find-skills` (jangan bikin yang sudah ada di komunitas).
2. Kalau perlu instal dari skills.sh/GitHub, perintah resminya:
   ```powershell
   npx skills add <repo-atau-URL> -a qoder
   npx skills add https://github.com/anthropics/skills --skill skill-creator -a qoder
   ```
   ⚠️ Ini mengunduh dari jaringan dan menulis ke folder profil → **harus atas persetujuan**,
   agen tidak menjalankannya sendiri.
3. **Bikin custom** kalau belum ada: `/create-skill <deskripsi>` → hasilnya `SKILL.md` yang
   sesuai spec; simpan di `~\.qoder\skills\` (user) atau `{repo}\.qoder\skills\` (proyek).
4. **Bungkus jadi plugin** kalau mau dipakai lintas mesin/repo: `/create-plugin`.
5. Catat di katalog §2 dan di `01-inventory.md` supaya tetap terbukti.

## 5. Aturan kualitas SKILL.md (ringkas, dari doc resmi + praktik)

- `description` menentukan kapan model memanggilnya: tulis kondisi pemicu, bukan cuma nama.
- Satu skill = satu pekerjaan spesifik; langkah terukur, dengan perintah yang benar-benar jalan.
- Sertakan "kapan **tidak** dipakai" untuk mencegah pemanggilan salah.
- Jangan menaruh rahasia, token, atau jalur ber-privilege tinggi di dalamnya.
- Kalau skill memanggil skrip, skripnya punya flag `-DryRun`/read-only dan aman dijalankan ulang.
