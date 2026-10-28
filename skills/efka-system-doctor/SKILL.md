---
name: efka-system-doctor
description: Run the local production-readiness doctor on this laptop and turn its output into concrete fixes. Use when the user asks to check system readiness, audit tooling, verify that the dev environment or the 9Router gateway is healthy, asks what is broken, or after installing/updating IDE plugins, Node, WSL, or 9Router. Also use before starting a large engineering task when environment state is uncertain. Does not install anything.
---

# Efka System Doctor

Single source of truth for this machine's engineering environment is
`<hub>\`. This skill runs its readiness gate and interprets the result.

## When to use

- "cek kesiapan sistem", "lingkungan dev masih oke?", "what's broken on this machine"
- after an IDE plugin/Node/WSL/9Router change, before a long build session
- when a scheduled doctor run reports FAIL

When NOT to use: for a bug inside a specific application (debug that app instead), or for
generic programming questions.

## Procedure

1. Run the doctor (read-only, safe to repeat):

   ```powershell
   powershell -ExecutionPolicy Bypass -File "<hub>\scripts\system-doctor.ps1"
   ```

   Exit code: `0` = no FAIL, `1` = at least one FAIL. Add `-Json` when you need to parse the
   rows, `-SkipWsl` when the WSL section is irrelevant or the VM must stay asleep.

2. Read the rows in this order: `FAIL` first, then `WARN`. Each row already carries the fix
   hint in `Detail`. Areas used: `toolchain`, `plugin`, `skill`, `mcp`, `wsl`, `9router`,
   `project`, `capacity`.

3. Map each finding to the matching section of `<hub>\docs\05-roadmap.md`
   (items are numbered and some are explicitly "needs approval"). Do not invent new global
   changes from a doctor row.

4. Report to the user as: counts (FAIL/WARN/OK/INFO), the top blocking rows verbatim, the
   fix command for each, and whether that fix needs their approval.

## Known fixes referenced by the doctor

| Finding | Fix (already exists on this host) |
|---|---|
| `wsl` FAIL on `vmIdleTimeout` / `instanceIdleTimeout` | `powershell -ExecutionPolicy Bypass -File <9Router-Backup>\restore-wslconfig-idle.ps1` (merges, never overwrites) |
| `wsl` FAIL on autostart task | `… <9Router-Backup>\files\install-9router-autostart.ps1` |
| `9router` FAIL "pins a different digest" | `… <9Router-Backup>\sync-default-project.ps1`, then `compare-locations.ps1` |
| `9router` WARN gateway HTTP empty | gateway is only up when WSL runs: `wsl -d Ubuntu-24.04 -- systemctl --user start 9router-podman.service` |
| `project` WARN "git=False" | needs user approval: `git init` + a `.gitignore` that excludes archives and credentials |
| `mcp` WARN pinned winget node path | needs user approval: set `"command": "node"` in `~\.qoder\mcp.json`, then re-verify the server |

## Guardrails

- The doctor must stay read-only. Never add a mutating command to it.
- Never print the contents of `~\.qoder\mcp-router.json`, `~\.mcp-auth\`, or any 9Router
  credential/volume data. Paths and ages only.
- Anything requiring network install (plugins, `npx skills add`, MCP servers, winget
  upgrades) is a proposal to the user, not an action.
- If the doctor itself errors, say so plainly; do not report an environment as healthy.
