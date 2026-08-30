#!/bin/bash
set -e
echo "=== Efka Engineering System — install ==="
mkdir -p ~/.config/opencode/themes ~/.config/opencode/plugins ~/.config/opencode/agents ~/.config/opencode/skills ~/.config/opencode/commands
cp opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc
cp opencode/tui.json ~/.config/opencode/tui.json
cp opencode/themes-pi-harness.json ~/.config/opencode/themes/pi-harness.json
cp opencode/opencode-mem.jsonc ~/.config/opencode/opencode-mem.jsonc
cp opencode/AGENTS.md ~/.config/opencode/AGENTS.md
echo "Copy agents/skills/commands? See opencode/ lists — manual curated via wshobson"
echo "Run: codegraph install --target opencode --yes"
echo "Restart: quit opencode -> opencode, then /theme pi-harness"
echo "9Router: http://127.0.0.1:20128 (700 models)"
