# TASK CONTRACT — <judul pekerjaan>

Diisi **sebelum** pekerjaan dimulai. Satu file per pekerjaan; simpan di `docs/tasks/<tanggal>-<slug>.md`.
Tanpa kontrak, agen tidak boleh mulai menulis kode.

Blok di bawah ini **dibaca mesin**. `scripts/admit-task.ps1` menolak task yang tidak memenuhinya
(exit 1 + daftar masalah), lalu menulis `logs/jobs/<job_id>/state.json` berstatus `admitted`.

```yaml
---
job_id: 20261028-example-slug          # unik, dipakai sebagai nama folder job
goal: Satu kalimat hasil yang bisa diuji (minimal 10 karakter)
scope:                                 # direktori/file yang boleh disentuh
  - src/
  - tests/
acceptance:                            # perintah yang harus lulus, persis apa adanya
  - powershell -File ./check.ps1
stop_condition: Berhenti dan tulis handoff bila acceptance gagal 2x berturut-turut
limits:
  timeout_min: 90
  trust_profile: execute-sandboxed      # read-only | write-scoped | execute-sandboxed
image: docker.io/library/alpine@sha256:c64c687cbea9300178b30c95835354e34c4e4febc4badfe27102879de0483b5e
---
```

## 1. TaskSpec

| Field | Isi |
|---|---|
| Goal | satu kalimat, hasil yang bisa diuji |
| Non-goals | apa yang **tidak** dikerjakan (mencegah scope creep) |
| Repo & commit awal | `path` @ `sha` |
| Scope | direktori/file yang boleh disentuh |
| Acceptance | daftar perintah/tes yang harus lulus, persis |
| Trust profile | `read-only` · `write-scoped` · `execute-sandboxed` |
| Model/provider | yang disetujui untuk pekerjaan ini |
| Budget | maksimum langkah / token / waktu |
| Stop condition | apa yang memaksa berhenti dan menyerahkan handoff |

## 2. ExecutionSpec

| Field | Isi |
|---|---|
| Image / digest | hanya bila memakai sandbox; pin digest |
| Mounts | path repo saja; **tidak** home, `/mnt/c`, kredensial, socket |
| Writable roots | daftar eksplisit |
| Network | `none` (default) atau daftar tujuan yang diizinkan |
| Limits | CPU, RAM, PID, ukuran output, waktu |
| Toolchain | versi compiler/runner yang diharapkan |

## 3. JobState

`queued` → `running` → (`awaiting_approval`) → `verifying` → `completed`
Cabang gagal: `failed` · `cancelled` · `interrupted` · `reconciliation_required`

Aturan: `interrupted` hanya boleh diulang bila efek sampingnya dapat dipastikan belum terjadi
atau idempoten. Jika tidak pasti → `reconciliation_required`, jangan retry buta.

## 4. Evidence yang harus dikumpulkan

Setiap aksi bermutasi menghasilkan satu receipt (lihat `EVIDENCE_RECEIPT.md`):
command/argv, exit code, output (dipotong + hash), diff, verifier result, risiko tersisa.

## 5. Definition of done

- [ ] task sudah `admitted` oleh `scripts/admit-task.ps1` (state.json ada)
- [ ] semua perintah acceptance dijalankan **dan** hasilnya dilampirkan
- [ ] tidak ada perubahan di luar `scope`
- [ ] `check.ps1` proyek hijau
- [ ] review oleh pemeriksa terpisah (lihat `review-output.schema.json`) dengan `verdict: approve`
- [ ] handoff ditulis bila ada pekerjaan lanjutan
