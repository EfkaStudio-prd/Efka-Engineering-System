# CONTRACTS - apa yang harus benar sebelum "selesai"

Empat kontrak kecil yang membuat pekerjaan bisa diperiksa mesin. Semuanya tersedia sebagai
template di `core/templates/`.

| Kontrak | Template | Dipakai kapan | Penegak |
|---|---|---|---|
| **Task** | `TASK_CONTRACT.md` | sebelum menulis kode | manusia + review |
| **Evidence** | `EVIDENCE_RECEIPT.md` | setiap aksi bermutasi | otomatis untuk eksekusi (`sandbox-run.ps1`) + review |
| **Review** | `review-output.schema.json` | sebelum merge | `scripts/validate-review.ps1` |
| **Handoff** | `HANDOFF.md` | pindah sesi/agen, atau konteks penuh | manusia |

## 1. Aturan yang membuat kontrak ini berguna

1. **Tanpa bukti bukan temuan.** Finding tanpa kutipan/output atau langkah reproduksi ditolak
   validator (`evidence` < 8 karakter).
2. **`approve` butuh tes yang benar-benar jalan**: minimal satu entri `tests_observed` dengan
   `result: pass` dan `exit_code: 0`, serta tidak ada finding `critical`/`high`.
3. **Klaim harus cocok dengan receipt.** Bila entri `tests_observed` menyertakan `receipt`,
   validator membuka file receipt itu dan menolak bila: file tidak ada, `exit_code` berbeda,
   verdict receipt bukan `pass` padahal tes diklaim `pass`, atau receipt tidak memuat pin image.
4. **`not_run` bukan hasil.** Boleh dicatat, tidak boleh dipakai untuk menyatakan selesai.
5. **Independensi diakui, bukan diklaim.** Reviewer dengan model/upstream sama menulis
   `independent: false`; keputusan merge oleh manusia tetap sadar akan hal itu.
6. **Non-idempoten butuh `operation_id`.** Tanpa itu, pekerjaan yang terputus berstatus
   `reconciliation_required`, bukan diulang buta.

## 2. Bentuk receipt yang dihasilkan sistem

`scripts/sandbox-run.ps1` menulis `logs/sandbox/sandbox-<ts>.json` untuk setiap eksekusi:

```json
{
  "receipt_id": "…",
  "timestamp": "2026-10-28T13:11:30",
  "tool": "sandbox-run",
  "argv": ["sh", "-lc", "npm test"],
  "cwd": "/work",
  "host_workdir": "C:\\work\\api",
  "mount_mode": "rw",
  "image": "docker.io/library/alpine@sha256:c64c687c…",
  "network": "none",
  "limits": { "memory_mb": 2048, "cpus": 1, "pids": 128, "timeout_s": 600 },
  "exit_code": 0,
  "duration_ms": 41233,
  "output": { "bytes": 9120, "sha256": "…", "excerpt": "…" },
  "limits_enforced": true,
  "verdict": "pass"
}
```

Yang membuatnya berguna: `image` (pin), `limits` (apa yang ditegakkan), `exit_code`, dan
`output.sha256` (isi output tidak bisa diubah tanpa mengubah hash).

## 3. Contoh: review yang mengutip receipt

```json
{
  "verdict": "approve",
  "independent": true,
  "findings": [],
  "tests_observed": [
    { "command": "npm test", "result": "pass", "exit_code": 0,
      "receipt": "logs/sandbox/sandbox-20261028-131130.json" }
  ]
}
```

```powershell
Get-Content .\review.json -Raw | .\scripts\validate-review.ps1
# review OK: verdict=approve findings=0 tests=1 independent=True      (exit 0)

# receipt dihapus / exit_code diubah -> validator menolak
#   - receipt not found: …
#   - receipt exit_code mismatch for 'npm test' (claimed 0, receipt 1) (exit 1)
```

## 4. Yang belum ditegakkan (jujur)

- **TaskSpec belum ditegakkan mesin.** Belum ada admission control yang menolak task tanpa
  acceptance criteria, budget, atau stop condition. Saat ini masih disiplin manusia + review.
- **Receipt baru otomatis untuk eksekusi.** Edit file, keputusan desain, dan review belum
  menghasilkan receipt otomatis; itu dicatat manual di `HANDOFF.md`/review JSON.
- **Independensi reviewer masih flag.** Belum ada mekanisme yang membuktikan reviewer memakai
  model/upstream berbeda.

Fase berikutnya (lihat `docs/SCORE.md`): admission control untuk TaskSpec dan reviewer kedua
independen (P2), lalu matriks eval + CI (P3).
