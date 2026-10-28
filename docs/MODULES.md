# MODULES — cara memakai sistem lain tanpa mencampurnya

EES berdiri sendiri. Semua yang lain adalah **modul**: dipakai, diverifikasi, tetapi tidak
diinstal atau dikonfigurasi oleh EES.

## 1. Kontrak modul

Sebuah modul layak disebut modul bila:

1. punya cara verifikasi sendiri yang **read-only** dan mengembalikan exit code;
2. mengungkap versi/digest yang bisa dipin;
3. tidak menulis ke `core/`, `docs/`, atau `templates/` milik EES;
4. kredensialnya dibaca dari environment, bukan dari file di repo.

## 2. Cara memasang pemeriksaan modul

Buat folder di mesinmu (bukan di repo ini):

```
adapters/<nama-modul>/README.md    # apa yang dibutuhkan, cara memverifikasi manual
adapters/<nama-modul>/verify.ps1   # exit 0 = sehat, 1 = perlu tindakan
```

`scripts/verify-all.ps1` otomatis menjalankan setiap `adapters/*/verify.ps1` yang ditemukan dan
memasukkan hasilnya sebagai seksi `adapter:<nama>`.

Kerangka `verify.ps1`:

```powershell
[CmdletBinding()] param()
$ErrorActionPreference = 'Continue'
$fail = 0

# 1) cek yang murah dan objektif dulu (versi, digest, port, file wajib)
# 2) jalankan probe fungsional (HTTP, CLI, query)
# 3) cetak baris ringkas: apa yang diperiksa, hasilnya
if ($fail -gt 0) { exit 1 }
exit 0
```

Aturan: jangan menaruh token di adapter, jangan mengubah state modul saat verifikasi, dan jangan
menganggap "proses hidup" sebagai bukti "layanan sehat" — probe hasil nyata.

## 3. Contoh modul yang biasa dipakai bersama EES

| Modul | Verifikasi yang wajar | Catatan |
|---|---|---|
| Gateway model lokal (mis. 9Router) | HTTP endpoint, digest image, data dir, bind loopback | **jangan** diinstal oleh EES |
| Container runtime (rootless Podman) | versi, rootless, cgroup v2, image terpin | dipakai oleh executor; EES tidak memasang/mengonfigurasi |
| Eval harness | dataset terpin, runner, output JSON | dipakai berkala, bukan setiap commit |
| Browser automation | versi engine, profil terisolasi | kredensial tidak masuk repo |

Catatan penting soal Podman: ia **bukan** modul yang diverifikasi lewat adapter, tetapi runtime yang
dipakai `scripts/sandbox-run.ps1`. Bedanya, preflight executor sudah menjadi verifikasinya: distro
WSL ada, Podman rootless jalan, dan image dengan digest terpin tersedia. Bila salah satu tidak ada,
eksekusi `BLOCKED` - bukan fallback.

## 4. Anti-pola

- Menyalin skrip modul ke `core/` supaya "praktis" → mencampur host dengan sistem.
- Menaruh path host di `manifest.json` → instalasi mesin lain rusak.
- Menjalankan modul dari dalam gate tanpa timeout/limit → gate menggantung.
- Menyebut status modul sebagai bagian dari status EES → laporan jadi ambigu.
- Menarik image atau memasang runtime dari dalam gate → gate berubah jadi installer.
