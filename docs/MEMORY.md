# MEMORY — apa yang disimpan agen, di mana, dan untuk berapa lama

Tiga tempat berbeda; jangan dicampur.

| Tempat | Isi | Umur | Siapa yang menulis |
|---|---|---|---|
| **Memori agen** (Qoder/Claude/Codex) | preferensi, pelajaran, pitfall, keputusan | lintas sesi | agen, dengan aturan di §2 |
| **`AGENTS.md` repo** | perintah, invarian, jebakan proyek | selama repo hidup | manusia + review |
| **Dokumen kerja** (`TASK_CONTRACT`, `HANDOFF`, ADR) | state pekerjaan & keputusan | per pekerjaan / permanen | agen + manusia |

## 1. Hierarki otoritas

1. Kontrak pekerjaan & ADR di repo — mengikat.
2. `AGENTS.md` — konteks dan aturan.
3. Memori agen — bantuan recall, **bukan** sumber kebenaran.
4. Ringkasan/compaction — hanya derived context; tidak pernah menggantikan kontrak.

## 2. Aturan memori agen

**Tulis** bila: kesalahan berulang, keputusan arsitektur yang mahal dibalik, konvensi yang
terbukti dipakai, atau preferensi eksplisit pengguna.

**Jangan tulis**: nilai rahasia, perintah destruktif, fakta yang bisa disimpulkan dari kode,
kondisi sementara (versi tool), atau catatan rapat tanpa keputusan.

**Bentuk**:

- satu memori = satu topik; perbarui yang ada daripada membuat duplikat;
- pitfall: gejala → akar masalah → pola perbaikan → batas keberlakuan;
- keputusan: kesimpulan → alasan trade-off → alternatif yang ditolak → kapan kedaluwarsa;
- pengalaman tool: skenario → cara pakai → catatan (generalisasi, bukan path proyek).

**Rawat**: bila memori bertentangan dengan kenyataan (kode/log), perbaiki memorinya, bukan
kenyataannya. Duplikat yang tumpang tindih digabung ke versi terlengkap.

## 3. Compaction dan konteks

- Ringkasan boleh mengubah **apa yang model lihat**, bukan **apa yang terjadi**. Kontrak, acceptance,
  dan bukti tetap disimpan di dokumen.
- Sebelum konteks penuh, tulis `HANDOFF.md` dan berhenti dengan status yang jujur
  (`interrupted`/`awaiting_approval`), jangan memotong aturan penting.
- Output tool besar dipotong dengan batas eksplisit dan hash; jangan menyimpan dump mentah.

## 4. Anti-pola

- Menyalin isi `AGENTS.md` ke memori (duplikasi yang cepat basi).
- Menyimpan path/versi host di memori global.
- Menyebut "sudah selesai" tanpa receipt/exit code.
- Memori otomatis (plugin) yang menulis tanpa review: tunda sampai ada bukti manfaat.
