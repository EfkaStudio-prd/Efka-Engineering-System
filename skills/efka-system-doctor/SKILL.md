---
name: efka-system-doctor
description: Run the Efka Engineering System readiness doctor and production gate on this machine, then turn the output into concrete fixes. Use when asked to check system readiness, audit tooling, verify the engineering environment, asks what is broken, or after installing/updating an IDE agent, Node, PowerShell, or a local service. Also use before starting a large task when environment state is uncertain. Read-only; installs nothing.
---

# Efka System Doctor

EES is the control layer: it checks, enforces invariants, and records evidence. It never installs
modules (gateway, sandbox, agents) for you.

## Procedure

1. Run the doctor (fast, per-item):

   ```powershell
   powershell -ExecutionPolicy Bypass -File "<hub>\scripts\system-doctor.ps1"
   ```

2. Run the gate (doctor + secrets + sandbox preflight + every `adapters/*/verify.ps1`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File "<hub>\scripts\verify-all.ps1"
   # add -DeepSandbox to run the 10-case execution-boundary self-test (~20 s)
   ```

   `<hub>` = the folder that contains `manifest.json` (default `%USERPROFILE%\Efka Engineering System`).
   Exit `0` = no FAIL, `1` = at least one FAIL. Use `-NoLog` for ad-hoc runs.

3. Read results in this order: `FAIL` → `WARN`. Each row already carries the hint.
   Areas: `toolchain`, `agent`, `mcp`, `repo`, `secrets`, `capacity`, `sandbox`, `sandbox:selftest`,
   `adapter:<name>`.

4. Report to the user: counts (FAIL/WARN/OK/INFO), the failing rows verbatim, the fix command,
   and whether the fix needs their approval.

## Interpretation rules

- `INFO: not installed (optional)` is not a problem. `podman` on the Windows PATH is optional; the
  executor probes WSL podman itself and reports it as the `sandbox` section.
- `WARN: execution boundary unavailable: image not usable` means the pinned image is missing or its
  digest does not match: `podman pull` the pinned image, then compare with `podman inspect`.
- `WARN: child process could not start` means a restricted environment (IDE sandbox) blocked a
  child process — re-run from a normal terminal; do not "fix" it in the scripts.
- A `repo` WARN about `hooksPath=unset` means the secret guard is not wired there:
  `git -C <repo> config core.hooksPath "<hub>/githooks"`.
- A module's health (gateway, eval, agent surface) only appears as `adapter:<name>`; if that section
  is missing, the module is simply not installed — that is not an EES failure. The execution boundary
  is the exception: it is core, so it reports as `sandbox`.

## Running work inside the boundary

```powershell
powershell -ExecutionPolicy Bypass -File "<hub>\scripts\sandbox-run.ps1" `
  -Command 'npm ci && npm test' -WorkDir '<repo>' -WorkWrite -TimeoutSec 600 -MemoryMB 2048
```

Exit `2` = BLOCKED (no podman / image / digest mismatch): report it, never retry on the host shell.
Every run writes `logs\sandbox\sandbox-<ts>.json`; quote that path as the receipt when claiming a
test passed.

## Guardrails

- Never add a mutating step to the doctor or gate.
- Never print contents of credential files; paths and ages only.
- Anything requiring network install (tool, plugin, MCP) is a proposal, not an action.
- If the gate itself errors, say so; never report an environment as healthy.
