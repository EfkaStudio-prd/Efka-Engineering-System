# HANDOFF — <tanggal> — <slug>

Dipakai ketika pekerjaan berpindah sesi/agen/manusia. Tulis fakta, bukan narasi.

## Status

| Field | Isi |
|---|---|
| JobState | `running` / `awaiting_approval` / `verifying` / `interrupted` / `reconciliation_required` |
| Repo @ commit | `path` @ `sha` |
| Scope yang sudah berubah | daftar file |
| Scope yang **belum** tersentuh | daftar file/folder |

## Yang sudah terbukti

- perintah + hasil (tempel baris ringkas, bukan paragraf)
- tes yang lulus/gagal beserta exit code

## Yang belum terbukti

- asumsi yang masih perlu diuji
- efek samping yang statusnya tidak diketahui (wajib `reconciliation_required`)

## Langkah berikutnya (maks 5)

1. …
2. …

## Jangan dilakukan

- hal yang sudah dicoba dan gagal, beserta alasannya
- perubahan di luar scope kontrak
