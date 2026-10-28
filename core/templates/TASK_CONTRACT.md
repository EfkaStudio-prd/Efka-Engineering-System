# TASK CONTRACT — <judul pekerjaan>

Diisi **sebelum** pekerjaan dimulai. Satu file per pekerjaan; simpan di `docs/tasks/<tanggal>-<slug>.md`.
Tanpa kontrak, agen tidak boleh mulai menulis kode.

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

- [ ] semua perintah acceptance dijalankan **dan** hasilnya dilampirkan
- [ ] tidak ada perubahan di luar `scope`
- [ ] `check.ps1` proyek hijau
- [ ] review oleh pemeriksa terpisah (lihat `review-output.schema.json`) dengan `verdict: approve`
- [ ] handoff ditulis bila ada pekerjaan lanjutan
