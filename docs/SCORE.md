# SCORE — seberapa siap sistem ini untuk engineering

Dua rubrik, dua pertanyaan. Jangan dicampur.

| Pertanyaan | Skor | Arti |
|---|---|---|
| Apakah infrastruktur pengelolaannya rapi? | **85 / 100** | dokumen, gate, skill, version control, observabilitas |
| Apakah sistem ini mampu *menghasilkan software berkualitas secara konsisten*? | **44 / 100** | kematangan harness engineering (level 2 dari 5) |

Rubrik kedua diturunkan dari lapisan yang dipakai riset R0/R1: isolasi eksekusi, kontrak
pekerjaan, evidence, verifier independen, kontrak review, memori, observabilitas, eval.

| Lapisan | Bobot | Skor | Kondisi |
|---|---|---|---|
| Version control & kontrol perubahan | 8 | 9 | repo + tag + hook rahasia; belum ada remote otomatis |
| Gerbang verifikasi otomatis | 10 | 9 | doctor + gate + exit code |
| Eksekusi terisolasi | 15 | **2** | belum ada eksekusi kerja di dalam boundary |
| Kontrak pekerjaan (TaskSpec/JobState) | 12 | **1** | belum ada |
| Evidence receipt per aksi | 10 | **2** | log gate saja |
| Verifier independen | 10 | 3 | verifikasi fakta ada; reviewer terpisah belum |
| Kontrak review + independence | 8 | 2 | belum ada schema/flag |
| Memori & konteks | 10 | 6 | memori + AGENTS; HANDOFF/ADR belum |
| Observabilitas & eval | 9 | 5 | log + task; matriks eval belum |
| Toolchain | 8 | 8 | pwsh/jq/gh/rg lengkap |

**Tertimbang: 44/100.** Level: *instrumented but unguarded* — sistem tahu keadaannya,
tetapi pekerjaan agen belum berjalan di dalam batas yang bisa ditegakkan.

## Jalur ke 80

| Fase | Isi | Skor |
|---|---|---|
| P0 | kontrak kerja, schema review + validator, ADR/HANDOFF, klausa fail-closed, matriks 12 kasus | 44 → 61 |
| P1 | executor Podman (image dipin, `--network none`, read-only, limit) + 8 fault test | 61 → 70 |
| P2 | reviewer kedua independen, eval berkala, CI menjalankan gate | 70 → 80 |

## Cara mengukur ulang

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-all.ps1
```

Skor di atas adalah penilaian berbobot terhadap rubrik yang ditulis di sini — bukan benchmark
eksternal. Setiap kenaikan harus disertai bukti baru (test hijau, log, artefak), bukan klaim.
