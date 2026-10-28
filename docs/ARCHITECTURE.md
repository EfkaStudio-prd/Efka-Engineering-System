# ARCHITECTURE — apa yang EES miliki dan apa yang bukan

EES adalah **lapisan kontrol** untuk pekerjaan engineering: memeriksa kesiapan, menegakkan
invarian, menyediakan kontrak, dan mencatat bukti. EES **bukan** aplikasi, bukan gateway model,
dan bukan installer untuk layanan lain.

```
                 ┌──────────────────────────────────────────┐
   agen/CLI ────►│ core/  (scripts, githooks, templates)    │
                 │  doctor · gate · secret-scan · scaffold  │
                 └───────────────┬──────────────────────────┘
                                 │ memeriksa & memanggil
                 ┌───────────────▼──────────────────────────┐
                 │ adapters/<host>/verify.ps1  (opsional)   │
                 │  modul eksternal: layanan lokal, WSL,    │
                 │  sandbox, dst. — tidak ikut tercopy      │
                 └──────────────────────────────────────────┘
```

## 1. Tiga lapisan

| Lapisan | Isi | Aturan |
|---|---|---|
| **core** | skrip pemeriksa, hook, template, skill generik | tidak boleh tahu nama host, path pengguna, atau produk tertentu |
| **adapters** | pemeriksaan khusus host/modul, hidup di mesin itu | tidak pernah disalin ke mesin lain; membaca konfigurasi dari environment |
| **modules** | sistem lain yang **dipakai** (gateway model, sandbox, eval) | tidak diinstal oleh EES; hanya diverifikasi bila sudah ada |

Modul **bukan** milik repositori ini. Contoh: 9Router, Podman sandbox, eval harness, browser
automation. EES tidak memasang, tidak mengonfigurasi, dan tidak meng-hardcode modul apa pun.

## 2. Aliran kerja yang ditegakkan

1. **Kontrak** (`TASK_CONTRACT.md`) — goal, scope, acceptance, budget, stop condition.
2. **Eksekusi** — agen bekerja di dalam scope; setiap aksi bermutasi menghasilkan receipt.
3. **Verifikasi** — `scripts/verify-all.ps1` + `check.ps1` proyek; hasil berupa exit code dan log.
4. **Review** — keluaran JSON sesuai `review-output.schema.json`, diperiksa `validate-review.ps1`.
5. **Handoff** — bila pekerjaan berpindah sesi/agen (`HANDOFF.md`).

Tanpa langkah 1 dan 3, "selesai" hanya klaim.

## 3. Invarian

1. Tidak ada nilai kredensial di repo; semuanya dari environment (`secrets.example.env`).
2. Satu sumber kebenaran: instalasi dihasilkan dari repo ini.
3. Setiap pemeriksaan read-only dan mengembalikan exit code bermakna.
4. **Fail-closed**: kapabilitas yang tidak didukung → `BLOCKED`, bukan fallback diam-diam.
5. Reviewer yang memakai model/upstream sama dengan implementer wajib menandai `independent: false`.

## 4. Yang sengaja tidak ada di sini

- Runtime agen (Qoder/OpenCode/Codex/Claude) — itu host, bukan EES.
- Gateway model dan routing provider.
- Sandbox/container manager: EES hanya **memverifikasi** batasnya lewat adapter.
- Dashboard, database, atau layanan jaringan.

Menambahkan salah satu di atas ke dalam `core/` adalah regresi arsitektur.
