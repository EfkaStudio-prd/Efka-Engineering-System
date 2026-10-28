# CONTRACTS — apa yang harus benar sebelum "selesai"

Empat kontrak kecil yang membuat pekerjaan bisa diperiksa mesin. Semuanya tersedia sebagai
template di `core/templates/`.

| Kontrak | Template | Dipakai kapan | Penegak |
|---|---|---|---|
| **Task** | `TASK_CONTRACT.md` | sebelum menulis kode | manusia + review |
| **Evidence** | `EVIDENCE_RECEIPT.md` | setiap aksi bermutasi | review + log |
| **Review** | `review-output.schema.json` | sebelum merge | `scripts/validate-review.ps1` |
| **Handoff** | `HANDOFF.md` | pindah sesi/agen, atau konteks penuh | manusia |

## 1. Aturan yang membuat kontrak ini berguna

1. **Tanpa bukti bukan temuan.** Finding tanpa kutipan/output atau langkah reproduksi ditolak
   validator (`evidence` < 8 karakter).
2. **`approve` butuh tes yang benar-benar jalan**: minimal satu entri `tests_observed` dengan
   `result: pass` dan `exit_code: 0`, serta tidak ada finding `critical`/`high`.
3. **`not_run` bukan hasil.** Boleh dicatat, tidak boleh dipakai untuk menyatakan selesai.
4. **Independensi diakui, bukan diklaim.** Reviewer dengan model/upstream sama menulis
   `independent: false`; keputusan merge oleh manusia tetap sadar akan hal itu.
5. **Non-idempoten butuh `operation_id`.** Tanpa itu, pekerjaan yang terputus berstatus
   `reconciliation_required`, bukan diulang buta.

## 2. Contoh menjalankan validator

```powershell
Get-Content .\review.json -Raw | .\scripts\validate-review.ps1
# review OK: verdict=approve findings=0 tests=2 independent=True   (exit 0)

.\scripts\validate-review.ps1 -Path .\review.json
# review INVALID: 1 problem(s)
#   - approve requires at least one tests_observed entry with result=pass and exit_code=0   (exit 1)
```

## 3. Yang belum ditegakkan (jujur)

Kontrak ini masih **dokumen + validator**, belum sebuah workflow yang memaksa. Penegakan
sepenuhnya baru terjadi setelah:
eksekusi dijalankan di sandbox dengan limit, receipt dikumpulkan otomatis oleh harness,
dan review dijalankan pemeriksa terpisah. Itu fase berikutnya (lihat `docs/SCORE.md`).
