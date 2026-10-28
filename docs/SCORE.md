# SCORE - seberapa siap sistem ini untuk engineering

Dua rubrik, dua pertanyaan. Jangan dicampur.

| Pertanyaan | Skor | Arti |
|---|---|---|
| Apakah infrastruktur/pengelolaannya rapi? | **85 / 100** | dokumen, gate, hook, skill, version control, observabilitas |
| Apakah sistem mampu *menghasilkan software berkualitas secara konsisten*? | **70 / 100** | kematangan harness engineering (level 3 dari 5) |

Rubrik kedua diturunkan dari lapisan riset R0/R1: isolasi eksekusi, kontrak pekerjaan, evidence,
verifier independen, kontrak review, memori, observabilitas, eval.

| Lapisan | Bobot | Skor | Kondisi sekarang |
|---|---|---|---|
| Version control & kontrol perubahan | 8 | 9 | repo + tag + hook rahasia; belum ada remote otomatis |
| Gerbang verifikasi otomatis | 10 | 9 | doctor + gate + exit code + adapter modul + seksi sandbox |
| Eksekusi terisolasi | 15 | **8** | `sandbox-run.ps1`: image dipin, tanpa jaringan, rootfs read-only, satu mount, non-root, limit memori/CPU/PID, timeout + cleanup, fail-closed; 10 fault test hijau |
| Kontrak pekerjaan | 12 | **7** | `admit-task.ps1` menolak kontrak tanpa goal teruji/scope/acceptance/stop_condition/limit/trust profile; `state.json` per job. Scope belum dimonitor |
| Evidence receipt per aksi | 10 | **7** | receipt otomatis per eksekusi (image pin, limit, exit, hash output) + validator menolak klaim yang tidak cocok; aksi non-sandbox belum otomatis |
| Verifier independen | 10 | 3 | verifikasi fakta ada; reviewer terpisah belum |
| Kontrak review + independence | 8 | 6 | schema + `validate-review` menegakkan `approve` butuh tes lulus dan receipt yang konsisten |
| Memori & konteks | 10 | 7 | MEMORY.md + HANDOFF template; belum jadi kebiasaan terukur |
| Observabilitas & eval | 9 | 5 | log gate + receipt + retensi; matriks eval belum |
| Toolchain | 8 | 8 | pwsh/jq/gh/rg terdeteksi (termasuk di luar PATH) |

**Tertimbang: ±70/100.** Level: *admitted and guarded* - pekerjaan tidak bisa mulai tanpa kontrak yang
lolos admission, dan perintahnya berjalan di dalam batas yang mencatat bukti. Yang belum: pemantauan
scope, reviewer kedua, dan evaluasi berkala.

## Bukti kenaikan 52 -> 66

| Perubahan | Bukti |
|---|---|
| Boundary eksekusi benar-benar menahan | `tests/sandbox-selftest.ps1`: T1 jalan, T2 jaringan tertutup, T3 rootfs read-only, T4 tmpfs, T5 mount read-only, T6 timeout, T7 `memory.max` = 67108864, T8 image asing BLOCKED, T9 env tidak bocor, T10 receipt valid |
| Bukti otomatis, bukan klaim | setiap run menulis `logs/sandbox/*.json` dengan `image`, `limits`, `exit_code`, `output.sha256` |
| Klaim review harus cocok dengan bukti | `validate-review.ps1` menolak `receipt` yang hilang, `exit_code` berbeda, atau verdict receipt bukan `pass` |
| Gate tahu batasnya | `verify-all.ps1` menambah seksi `sandbox` (preflight) dan `-DeepSandbox` untuk 10 kasus penuh |

## Bukti kenaikan 66 -> 70

| Perubahan | Bukti |
|---|---|
| Kontrak ditegakkan mesin | `tests/admit-task-selftest.ps1`: template lolos (state.json dibuat), kontrak tanpa acceptance ditolak, `execute-sandboxed` tanpa digest ditolak, `job_id` buruk ditolak, input JSON diterima |
| Gate memeriksa keduanya | `verify-all -DeepSandbox` menambah seksi `sandbox:selftest` dan `contracts:selftest` |

## Jalur ke 82

| Fase | Isi | Skor |
|---|---|---|
| ~~P1~~ | ~~executor terisolasi + fault test~~ | 52 -> 66 (selesai) |
| ~~P2a~~ | ~~admission control untuk TaskSpec~~ | 66 -> 70 (selesai) |
| P2b | pemantauan scope (`git diff --name-only` vs `state.json`) + reviewer kedua independen | 70 -> 76 |
| P3 | eval berkala (matriks 12 kasus, hasil JSON + tren) + CI menjalankan gate di setiap PR | 76 -> 82 |

## Cara mengukur ulang

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-all.ps1 -DeepSandbox
```

Skor ini penilaian berbobot terhadap rubrik di halaman ini, bukan benchmark eksternal. Setiap
kenaikan harus disertai bukti baru (tes hijau, log, receipt) - bukan klaim.
