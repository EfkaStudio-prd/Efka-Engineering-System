# adapters/ — lapisan khusus host

`core/` sengaja generik: tidak tahu apa pun tentang WSL, Podman, 9Router, atau path pengguna.
Semua yang khusus satu mesin hidup di sini.

```
adapters/
  <nama>/
    README.md     # apa yang dibutuhkan host ini
    verify.ps1    # opsional: dipanggil otomatis oleh scripts/verify-all.ps1
```

Aturan:

1. Installer **tidak** menyalin folder ini ke mesin lain.
2. `verify.ps1` harus read-only dan mengembalikan exit code 0/1.
3. Rahasia dibaca dari environment, tidak pernah dari file di folder ini.

Contoh nyata (host penulis): adapter `9router-local` memverifikasi layanan Podman rootless di
WSL2, digest image yang dipin, dan jalur OAuth callback. Adapter itu sengaja **tidak** dipublikasikan
karena bergantung pada host; pola umumnya bisa kamu tiru untuk layanan lokalmu sendiri.
