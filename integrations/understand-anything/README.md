# Understand-Anything (add-on)

Turn any repository into an interactive knowledge graph you can explore, search, and ask
questions about. Upstream: <https://github.com/Egonex-AI/Understand-Anything> - MIT, ~88k stars,
TypeScript. It ships nine agent skills (`understand`, `understand-chat`, `understand-dashboard`,
`understand-diff`, `understand-domain`, `understand-explain`, `understand-figma`,
`understand-knowledge`, `understand-onboard`).

## Why it is in this repository

EES gates work but does not understand the codebase it is gating. This add-on gives the agent a
map before it plans: architecture, domains, diffs, and an explain/tour path. That improves the
contract phase (scope and acceptance) and review quality - it does not change any gate result.

## What it is not

- Not a module. Modules (gateway, eval, runtimes) are **verified**, never installed. An add-on is
  third-party *agent content* that a human installs on purpose.
- Not vendored. Nothing from upstream lives in this repository; the installer clones upstream at a
  pinned commit and links it. Upstream keeps its own license and release cadence.
- Not automatic. `install.ps1` without `-Yes` prints the plan and exits `2` (BLOCKED).

## Install (opt-in, ~40 MB clone)

```powershell
.\integrations\understand-anything\install.ps1 -DryRun   # plan: commit, paths, skills
.\integrations\understand-anything\install.ps1 -Yes      # clone at pin + link skills
.\integrations\understand-anything\install.ps1 -Uninstall
```

Default surface is Qoder (`%USERPROFILE%\.qoder\skills`); upstream's own installer does not map
Qoder, so EES supplies that mapping. Use `-Surface agents` for `~/.agents/skills` (Codex, Gemini,
OpenCode, Pi) or `-Surface all` for both.

After installing, restart the IDE and ask *"understand this repository"*.

State is recorded in `<hub>\logs\integrations\understand-anything.json`:
commit, upstream tag, checkout path, surfaces, and how many links were created.

## Pin policy

The pin is the release tag `v2.9.0` @ `f08763d11d0202a8a8f52b5dedda6d1b2e2ebac8` (2026-07-10), and it
lives in three places that are all checked: `install.ps1 -Tag/-Commit`, `verify.ps1 -Tag/-Commit`,
and `manifest.json`. Upstream `main` is ahead of the tag (last push 2026-10-26); that is deliberate -
a release tag is a stable pin, a moving branch is not. Bumping the pin is a deliberate change: read
the upstream diff, update all three places, run the gate, and commit the bump with the new commit in
the message.

## Verification

```powershell
powershell -File .\integrations\understand-anything\verify.ps1
# installed and consistent -> understand-anything: OK v2.9.0 pinned=f08763d11d02 skills=9 links=9 node v24.x
# not installed            -> understand-anything: not installed (optional add-on; ...)   (exit 0)
# drift / half-installed   -> understand-anything: FAIL ...                               (exit 1)
```

`verify-all.ps1` runs this automatically as section `integration:understand-anything`.

## Uninstall

`install.ps1 -Uninstall` removes only junctions that point into the Understand-Anything checkout.
Real directories are never touched. The checkout is kept because other surfaces may still use it;
delete `%USERPROFILE%\.understand-anything` manually if you want it gone.
