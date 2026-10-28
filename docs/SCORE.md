# SCORE — seberapa siap sistem ini untuk engineering

Dua rubrik, dua pertanyaan. Jangan dicampur.

| Pertanyaan | Skor | Arti |
|---|---|---|
| Apakah infrastruktur/pengelolaannya rapi? | **85 / 100** | dokumen, gate, hook, skill, version control, observabilitas |
| Apakah sistem mampu *menghasilkan software berkualitas secara konsisten*? | **52 / 100** | kematangan harness engineering (level 2 dari 5) |

Rubrik kedua diturunkan dari lapisan riset R0/R1: isolasi eksekusi, kontrak pekerjaan, evidence,
verifier independen, kontrak review, memori, observabilitas, eval.

| Lapisan | Bobot | Skor | Kondisi sekarang |
|---|---|---|---|
| Version control & kontrol perubahan | 8 | 9 | repo + tag + hook rahasia; belum ada remote otomatis |
| Gerbang verifikasi otomatis | 10 | 9 | doctor + gate + exit code + adapter modul |
| Eksekusi terisolasi | 15 | **2** | belum ada eksekusi kerja di dalam boundary |
| Kontrak pekerjaan | 12 | **4** | `TASK_CONTRACT` + JobState terdokumentasi; **belum ditegakkan** |
| Evidence receipt per aksi | 10 | **2** | template ada; pengumpulan masih manual |
| Verifier independen | 10 | 3 | verifikasi fakta ada; reviewer terpisah belum |
| Kontrak review + independence | 8 | **6** | schema + `validate-review` menegakkan `approve` butuh tes lulus |
| Memori & konteks | 10 | 7 | MEMORY.md + HANDOFF template; belum jadi kebiasaan terukur |
| Observabilitas & eval | 9 | 5 | log + retensi; matriks eval belum |
| Toolchain | 8 | 8 | pwsh/jq/gh/rg terdeteksi (termasuk di luar PATH) |

**Tertimbang: ±52/100.** Level: *contracted but unguarded* — kontrak dan gerbang sudah ada,
tetapi eksekusi belum berjalan di dalam batas yang bisa ditegakkan.

## Jalur ke 80

| Fase | Isi | Skor |
|---|---|---|
| P1 | executor terisolasi (image dipin, `--network none`, read-only, limit) + 8 fault test | 52 → 66 |
| P2 | pengumpulan receipt otomatis dari harness + reviewer kedua independen | 66 → 74 |
| P3 | eval berkala (matrix 12 kasus) + CI menjalankan gate di setiap PR | 74 → 82 |

## Cara mengukur ulang

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-all.ps1
```

Skor ini penilaian berbobot terhadap rubrik di halaman ini, bukan benchmark eksternal. Setiap
kenaikan harus disertai bukti baru (tes hijau, log, receipt) — bukan klaim.
