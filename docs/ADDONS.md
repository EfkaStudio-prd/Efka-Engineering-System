# ADD-ONS - konten agen pihak ketiga yang dipakai dengan sadar

EES punya tiga kategori. Jangan dicampur.

| Kategori | Siapa yang memasang | Ada di repo ini? | Contoh |
|---|---|---|---|
| **core** | EES sendiri | ya | gate, executor, admission, hook, template |
| **modul** | manusia, di luar EES | tidak | gateway model (9Router), container runtime, eval harness |
| **add-on** | manusia, lewat installer EES yang opt-in | hanya *wrapper*-nya | skill pihak ketiga seperti Understand-Anything |

## 1. Kenapa add-on dipisahkan

Modul adalah **layanan** yang diverifikasi lewat `adapters/<name>/verify.ps1`. Add-on adalah
**konten agen** (skill/plugin) yang menambah kemampuan berpikir, bukan layanan yang berjalan.
Keduanya tidak boleh diinstal diam-diam, tetapi add-on perlu tempat khusus karena ia mengubah
perilaku agen secara langsung.

## 2. Aturan add-on

1. **Opt-in eksplisit.** Installer wajib menolak tanpa `-Yes` dan keluar dengan kode `2` (BLOCKED),
   serta menyediakan `-DryRun` yang mencetak commit, path, dan daftar yang akan dipasang.
2. **Pin, bukan "latest".** Pin (tag rilis + commit sha) ditulis di tiga tempat - installer,
   verifier, dan `manifest.json`. `verifier` gagal bila checkout bergeser dari pin.
3. **Tidak di-vendor.** Isi upstream tidak disalin ke repo ini. Installer melakukan clone pada
   commit yang dipin, lalu menautkan (junction/symlink). Lisensi upstream tetap milik upstream.
4. **Lisensi kompatibel + atribusi.** Saat ini hanya MIT/Apache-2.0/BSD. Nama, URL, dan lisensi
   upstream wajib muncul di `README.md` add-on dan di `manifest.json`.
5. **Pin ke rilis, bukan ke branch.** Pin yang dipakai adalah tag rilis; `main` yang bergerak bukan
   pin. Bila upstream belum punya tag yang layak, commit sha boleh dipakai sebagai pin sementara.
6. **Hanya tautan, jangan timpa.** Bila sebuah direktori asli sudah ada di surface agen, installer
   melewatinya (bukan menghapusnya). Uninstall hanya menghapus tautan yang menunjuk ke checkout.
7. **Read-only saat verifikasi.** `verify.ps1` tidak boleh memperbaiki apa pun.
8. **Tidak menyentuh gate.** Status add-on muncul sebagai `integration:<name>` dan tidak boleh
   mengubah keputusan gate inti.

## 3. Menambah add-on baru

```
integrations/<nama>/
  README.md      # apa, kenapa, lisensi, pin, cara pakai, cara uninstall
  install.ps1    # -DryRun | -Yes | -Uninstall, pin di parameter, state di logs/integrations/
  verify.ps1     # exit 0 konsisten/hadir-tidak, 1 drift/separuh terpasang
```

Daftarkan di `manifest.json` bagian `addons` (nama, upstream, license, pin, surface), lalu
`docs/GATES.md` tidak perlu diubah karena seksi `integration:<name>` sudah otomatis.

## 4. Add-on yang tersedia

| Add-on | Upstream | Lisensi | Pin | Memberi apa |
|---|---|---|---|---|
| `understand-anything` | <https://github.com/Egonex-AI/Understand-Anything> | MIT | `v2.9.0` @ `f08763d11d0202a8a8f52b5dedda6d1b2e2ebac8` | 9 skill: peta arsitektur, domain, diff, explain, dashboard, onboarding |

Catatan jujur: add-on menaikkan kualitas konteks, bukan skor inti EES. Skor di `docs/SCORE.md`
hanya berubah bila kemampuan **inti** bertambah dan teruji.
