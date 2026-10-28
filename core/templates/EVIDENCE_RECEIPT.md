# EVIDENCE RECEIPT — <aksi>

Satu receipt per aksi bermutasi (edit, shell, migrasi, deploy). Disimpan bersama log job.

```yaml
receipt_id: <uuid>
job_id: <id kontrak>
timestamp: <ISO-8601>
actor: <agent|human> <name/version>
tool: <nama tool>            # edit | shell | git | db | http
argv: ["<arg0>", "<arg1>"]   # tanpa rahasia; sudah diredaksi
cwd: <path>
exit_code: <int>
duration_ms: <int>
output:
  lines: <int>
  bytes: <int>
  sha256: <hash output lengkap>
  excerpt: |                 # maksimum 40 baris / 4 KB
    <potongan relevan>
diff:
  files_changed: <int>
  patch_sha256: <hash>
  path_scope_ok: <true|false>
verifier:
  command: <perintah verifikasi>
  exit_code: <int>
  result: <pass|fail|not_run>
risk:
  level: <none|low|medium|high>
  notes: <risiko tersisa>
replay:
  idempotent: <true|false>
  operation_id: <id di sistem eksternal, bila ada>
```

Aturan:

1. `result: not_run` **tidak** boleh dipakai untuk menyatakan selesai.
2. Output yang dipotong wajib menyertakan `sha256` dari output lengkap.
3. `operation_id` wajib untuk aksi non-idempoten (deploy, pembayaran, migrasi).
4. Receipt tanpa `exit_code` dianggap tidak ada.

## Receipt yang dihasilkan sistem (eksekusi)

`scripts/sandbox-run.ps1` menulis bentuk ini secara otomatis ke `logs/sandbox/sandbox-<ts>.json`.
Field `image`, `limits`, `mount_mode`, `network`, dan `limits_enforced` hanya ada di receipt
eksekusi karena hanya eksekusi yang punya batas fisik:

```json
{
  "receipt_id": "<uuid>",
  "timestamp": "<ISO-8601>",
  "actor": "agent/<name>",
  "tool": "sandbox-run",
  "argv": ["sh", "-lc", "<perintah>"],
  "cwd": "/work",
  "host_workdir": "<path host>",
  "mount_mode": "ro|rw",
  "image": "<image>@sha256:<digest>",
  "network": "none|host",
  "limits": { "memory_mb": 0, "cpus": 0, "pids": 0, "timeout_s": 0 },
  "exit_code": 0,
  "duration_ms": 0,
  "output": { "bytes": 0, "sha256": "<64 hex>", "excerpt": "<40 baris pertama>" },
  "limits_enforced": true,
  "verdict": "pass|fail|timeout|blocked"
}
```

Aksi bermutasi lain (edit, migrasi, deploy) tetap memakai bentuk YAML di atas dan disimpan di
samping job. Saat sebuah tes diklaim `pass` di review, sertakan path receipt-nya: validator akan
membuka file itu dan menolak klaim yang tidak cocok.

