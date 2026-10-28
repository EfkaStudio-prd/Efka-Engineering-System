---
name: wsl-podman-service
description: Operate and upgrade rootless-Podman user services inside WSL2 on this host (9Router is the example). Use for "update 9Router", "restart the WSL gateway", "snapshot the podman volume before a change", "the localhost gateway is dead", or any change to a systemd user service running a podman container. Covers safe volume snapshots, digest pin updates, and verification. Not for Docker on Windows and not for containers outside WSL.
---

# WSL + rootless Podman service maintenance

Reference implementation on this host: `<9Router-Backup>\` (installer, updater, validator,
sync) with docs in `<9Router-Backup>\README.md`. Distro `Ubuntu-24.04`, Linux user `efka`.

## Non-negotiables learned the hard way

1. **The container is `--network host` and binds loopback only.** Published bridge ports do
   not work for the app's transient OAuth callback listeners; nothing may bind `0.0.0.0`.
2. **Rootless volume files are owned by mapped UIDs** (e.g. 100999). Plain `tar`/`cp` as the
   user fails on `0600` files and still writes a partial archive. Snapshot pattern:

   ```bash
   mount=$(podman volume inspect -f '{{.Mountpoint}}' <volume>)
   (umask 077; podman unshare tar -C "$mount" -cz -f - . > "$HOME/backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz")
   tar -tzf "$HOME/backup-….tar.gz" | wc -l   # always verify
   ```

3. **`wsl.exe` output read through redirected PowerShell is mojibake** (UTF-16LE). Have bash
   write to a file under `/mnt/c/...` and read the file instead.
4. **Image pins drift.** Always read the live value: `podman inspect --format '{{.ImageDigest}}' <container>`.
   A stale pin in an install script silently downgrades the service.
5. **WSL idle policy matters**: without `vmIdleTimeout=-1` and `instanceIdleTimeout=-1` in
   `%USERPROFILE%\.wslconfig`, the VM shuts down ~60s after idling and the gateway looks dead.

## Standard procedures

### Status / logs / restart

```powershell
wsl -d Ubuntu-24.04 -- systemctl --user status 9router-podman.service
wsl -d Ubuntu-24.04 -- podman logs --tail 100 9router
wsl -d Ubuntu-24.04 -- systemctl --user restart 9router-podman.service
```

Stop with the user service, never `podman stop <container>` while the service is active
(systemd recreates it). `wsl --shutdown` reclaims RAM and stops everything.

### Upgrade a container image

```powershell
powershell -ExecutionPolicy Bypass -File <9Router-Backup>\update-9router.ps1            # latest tag
powershell -ExecutionPolicy Bypass -File <9Router-Backup>\update-9router.ps1 -Tag 0.5.111
```

What it does (see `files/update-9router-image.sh`): pull → stop service → snapshot volume →
back up runner → rewrite its `image=` line to the new digest → start → wait for `HTTP 307` →
validate. If it fails before the runner rewrite, an EXIT trap restarts the old version, so a
botched run never leaves the gateway down. Rollback = restore the printed `.bak-<timestamp>`
runner and restart.

After any version change, keep pins honest:

```powershell
powershell -ExecutionPolicy Bypass -File <9Router-Backup>\sync-default-project.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File <9Router-Backup>\sync-default-project.ps1
powershell -ExecutionPolicy Bypass -File <9Router-Backup>\compare-locations.ps1
```

### Validate

```powershell
powershell -ExecutionPolicy Bypass -File <9Router-Backup>\verify-9router.ps1
```

Checks: readiness (HTTP 307), digest agreement, host network, loopback-only bind, mount
propagation, SQLite `integrity_check`, required data files, password-file mode, OAuth callback
path from both WSL and Windows. `verify-9router.ps1` derives the expected digest from the
running container, so it stays correct across upgrades.

## Data-safety checklist before touching a stateful service

- [ ] snapshot taken **while the service is stopped** (live SQLite copy is inconsistent)
- [ ] archive verified (`tar -tzf`) and mode `0600`
- [ ] rollback command written down before starting
- [ ] application's own migrations reviewed in the logs afterwards (`[DB][migrate]`)
- [ ] row counts / credentials proven intact before declaring success

Never delete a Podman volume to "reset" something. Never copy volume contents into a repo or
shareable document — they contain auth material.
