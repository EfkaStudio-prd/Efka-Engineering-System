# GATES - arti exit code dan apa yang diperiksa

Semua pemeriksaan EES bersifat **read-only**. Tidak ada gate yang memperbaiki sesuatu diam-diam.

## 1. Dua gerbang

| Perintah | Menjawab | Exit code |
|---|---|---|
| `scripts/system-doctor.ps1` | "apakah mesin ini siap?" | 0 = tidak ada FAIL, 1 = ada FAIL |
| `scripts/verify-all.ps1` | "apakah sistem secara keseluruhan masih sah?" | 0 = tanpa FAIL, 1 = ada FAIL |

`verify-all` menjalankan `doctor` + `scan-secrets` + preflight `sandbox` + setiap
`adapters/*/verify.ps1`, mencetak tabel seksi, lalu menulis `logs/verify-<timestamp>.json` dan
`.txt` (retensi 60 run).

## 2. Status yang dipakai

| Status | Arti | Tindakan |
|---|---|---|
| `OK` | memenuhi kriteria | - |
| `INFO` | tidak berlaku / opsional tidak ada | tidak perlu tindakan |
| `WARN` | jalan, tetapi ada risiko atau pekerjaan tertunda | keputusan manusia; catat alasannya |
| `FAIL` | melanggar invarian | wajib diperbaiki sebelum pekerjaan dianggap selesai |

Aturan: **FAIL tidak boleh diabaikan**, WARN tidak boleh menumpuk tanpa catatan.

## 3. Yang diperiksa `doctor`

- **toolchain**: `git` wajib; `node/npm/python/uv/pwsh/jq/gh/rg/podman` opsional.
  `pwsh` dan `jq` dicari juga di lokasi cadangan karena install via paket sering belum masuk PATH.
- **agent**: keberadaan konfigurasi + jumlah skill di Qoder/OpenCode/Claude/Codex.
- **mcp**: setiap server di konfigurasi user harus punya executable yang benar-benar ada.
- **repo**: status git, jumlah perubahan, dan apakah `core.hooksPath` terpasang.
- **secrets**: file kredensial tidak boleh berada di dalam hub.
- **capacity**: ruang disk minimum.

## 4. Seksi `sandbox` (batas eksekusi)

| Perintah | Arti | Exit |
|---|---|---|
| `sandbox-run.ps1 -Command x -DryRun` | preflight: distro WSL, rootless podman, image dengan digest terpin | 0 siap, 2 BLOCKED |

- Preflight yang gagal menjadi **WARN** secara default, karena mesin tanpa container tetap boleh
  dipakai untuk pekerjaan non-eksekusi. Pakai `-RequireSandbox` untuk menjadikannya FAIL.
- `-DeepSandbox` menjalankan dua self-test: `tests/sandbox-selftest.ps1` (10 kasus batas eksekusi)
  dan `tests/admit-task-selftest.ps1` (5 kasus admission kontrak). Ini yang membuat klaim
  "terisolasi" dan "kontrak ditegakkan" bisa diperiksa, bukan hanya dipercaya.
- Gate tidak pernah menarik image dan tidak pernah menjalankan container tanpa permintaan eksplisit.

## 5. Menambah pemeriksaan

1. Taruh di `core/scripts/` bila generik untuk semua mesin.
2. Taruh di `adapters/<host>/verify.ps1` bila khusus host/modul.
3. Keluarkan baris ringkas per item + exit code; jangan hanya `Write-Host`.
4. Daftarkan di `manifest.json` dan sebutkan di README bila ia komponen baru.

## 6. Membaca hasil dari otomasi

```powershell
powershell -File scripts/verify-all.ps1 -NoLog   # tanpa menulis log
$last = Get-ChildItem logs/verify-*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$j = Get-Content $last.FullName -Raw | ConvertFrom-Json
$j.fail    # 0 = hijau
$j.sections | Where-Object Status -ne 'OK' | Select-Object Section, Status, Detail
```

Gate bisa melaporkan `WARN: child process could not start` bila dijalankan di lingkungan yang
memblokir proses anak (mis. sandbox IDE). Itu bukan kegagalan sistem: jalankan dari terminal biasa.
