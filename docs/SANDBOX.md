# Execution boundary

Every command an agent runs for this system goes through `scripts/sandbox-run.ps1`
(`core/scripts/sandbox-run.ps1` in the repository). The host shell is never the
execution environment for work products; it is only the control plane.

## What the boundary enforces

| Control | Implementation | Verified by |
|---|---|---|
| Pinned image | `image@sha256:...` must appear in `RepoDigests`; no tag drift, no implicit pull | T8 |
| No network | `--network=none` unless `-AllowNetwork` | T2 |
| Read-only root filesystem | `--read-only` + tmpfs `/tmp` (64 MiB) | T3, T4 |
| Single mount | only `-WorkDir` at `/work`, read-only unless `-WorkWrite` | T5 |
| Unprivileged | `--userns=keep-id`, `--cap-drop ALL`, `--security-opt no-new-privileges` | T1 (`id -u` = host uid) |
| Memory limit | `--memory <MB>` (cgroup v2 `memory.max`) | T7 |
| CPU / PID limits | `--cpus`, `--pids-limit` | preflight + run |
| Wall clock | `timeout -k 2 <sec>`; container is force-removed afterwards | T6 |
| No host environment | only `HOME=/tmp` passed in | T9 |
| Evidence | JSON receipt per run in `logs/sandbox/` with image pin, limits, exit code, output SHA-256 | T10 |

Fail-closed rule: if podman, the distro, or the pinned image is missing, the run
exits `2` with `BLOCKED: ...`. There is no fallback to the host shell, and the
system does not pull images on its own.

## Usage

```powershell
# read-only inspection of a repository
.\scripts\sandbox-run.ps1 -Command 'ls /work; cat /work/package.json' -WorkDir 'C:\work\api'

# run a test suite with the workspace mounted writable
.\scripts\sandbox-run.ps1 -Command 'npm ci && npm test' -WorkDir 'C:\work\api' -WorkWrite -TimeoutSec 600 -MemoryMB 2048

# inspect the exact container invocation without running it
.\scripts\sandbox-run.ps1 -Command 'true' -WorkDir 'C:\work\api' -DryRun
```

Exit codes: `0` command succeeded, `1` command failed or timed out (receipt
`verdict` distinguishes `fail` from `timeout`), `2` BLOCKED.

## Image policy

The default image is a pinned Alpine digest, enough for shell, file, and network
checks. For language work, pin your own image and pass it with `-Image`:

```powershell
podman pull docker.io/library/node:22-alpine
podman inspect --format '{{index .RepoDigests 0}}' docker.io/library/node:22-alpine
.\scripts\sandbox-run.ps1 -Image 'docker.io/library/node@sha256:<digest>' -Command 'node -v' -WorkDir 'C:\work\api'
```

Images are pulled deliberately by a human, never by the system. A tag such as
`node:22-alpine` also works, but then the pin is whatever the local store holds;
record the digest in the task contract if reproducibility matters.

## Self-test

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\sandbox-selftest.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-all.ps1 -DeepSandbox -RequireSandbox
```

The self-test asserts observable behaviour (cgroup value, blocked egress,
read-only mounts, receipt contents), not configuration text. It needs about 20
seconds because two cases intentionally wait for the wall clock.

## Known limits

- Rootless podman only. A rootful container runtime would weaken the boundary,
  so it is not supported.
- The boundary isolates the process, not the kernel: it is a container, not a VM.
  Untrusted code that must not reach the kernel needs a VM or a separate host.
- `-WorkWrite` gives the command write access to that directory. That is the
  normal case for test runs; it is still the only writable host path.
- Windows paths are mounted through `/mnt/<drive>`. POSIX permissions do not map
  exactly on those mounts; use a WSL-native path when permission semantics matter.
