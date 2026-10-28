#!/usr/bin/env bash
# One-click installer for the Efka Engineering System (Linux / macOS / WSL).
#
#   curl -fsSL https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.sh | bash
#
# With PowerShell 7 available the full installer runs (skills, hooks, tasks).
# Without it, the portable core is copied and the doctor is skipped with a notice.
set -euo pipefail

REPO_SLUG="${EFKA_REPO_SLUG:-EfkaStudio-prd/Efka-Engineering-System}"
TARGET="${EFKA_TARGET:-$HOME/Efka Engineering System}"
PROFILE="${EFKA_PROFILE:-core}"

say()  { printf '\033[36m== %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m   %s\033[0m\n' "$1"; }
warn() { printf '\033[33m   %s\033[0m\n' "$1"; }

resolve_source() {
  local here
  here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
  if [ -d "$here/core" ]; then
    printf '%s' "$here"
    return
  fi
  say "bootstrap: downloading the repository"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/${REPO_SLUG}/archive/refs/heads/main.tar.gz" | tar -xz -C "$tmp"
  find "$tmp" -maxdepth 1 -type d -name '*-main' | head -1
}

SRC="$(resolve_source)"
say "install target: $TARGET"
mkdir -p "$TARGET"/{scripts,templates,tests,githooks,docs,adapters,integrations,logs}

copy_tree() { # $1 = source subdir, $2 = target subdir
  [ -d "$SRC/$1" ] || return 0
  cp -R "$SRC/$1/." "$TARGET/$2/"
  ok "$2 <- $1"
}

copy_tree core/scripts scripts
copy_tree core/templates templates
copy_tree core/tests tests
copy_tree core/githooks githooks
copy_tree integrations integrations
copy_tree docs docs
for meta in manifest.json README.md VERSION; do
  [ -f "$SRC/$meta" ] && cp "$SRC/$meta" "$TARGET/$meta"
done

if [ -d "$SRC/skills" ]; then
  for surface in "$HOME/.qoder/skills" "$HOME/.config/opencode/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    parent="$(dirname "$surface")"
    [ -d "$parent" ] || continue
    mkdir -p "$surface"
    cp -R "$SRC/skills/." "$surface/"
    ok "skills -> $surface"
  done
fi

if [ ! -d "$TARGET/.git" ]; then
  git -C "$TARGET" init -b main >/dev/null 2>&1 || git -C "$TARGET" init >/dev/null 2>&1 || true
  ok "git repository initialised"
fi
git -C "$TARGET" config core.hooksPath "$TARGET/githooks" || true
chmod +x "$TARGET/githooks/pre-commit" 2>/dev/null || true
ok "secret guard wired (core.hooksPath)"

if [ "$PROFILE" = "full" ]; then
  warn "profile 'full' has no extra lane any more: modules are verified through adapters/<name>/verify.ps1"
fi

if command -v pwsh >/dev/null 2>&1; then
  say "running the doctor (pwsh)"
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$TARGET/scripts/system-doctor.ps1" || true
else
  warn "PowerShell 7 not found - doctor/gate skipped. Install pwsh for the full gate."
  warn "  apt: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux"
fi

cat <<EOF

Installed. Next steps:
  1. gate        : pwsh -File "$TARGET/scripts/verify-all.ps1" -DeepSandbox
  2. new project : pwsh -File "$TARGET/scripts/New-EfkaProject.ps1" -Path <dir> -Name <name>
  3. read first  : $TARGET/docs/INSTALL.md
  4. execution   : pull a pinned image once, then pwsh -File "$TARGET/scripts/sandbox-run.ps1" -Command <cmd> -WorkDir <dir>
EOF
