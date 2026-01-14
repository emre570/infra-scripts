#!/usr/bin/env bash
set -euo pipefail

echo "[*] Infra bootstrap starting..."

########################################
# Utils
########################################
is_installed() {
  command -v "$1" >/dev/null 2>&1
}

########################################
# Detect sudo
########################################
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

########################################
# Detect active shell + rc file
########################################
if [[ -n "${ZSH_VERSION:-}" ]]; then
  ACTIVE_SHELL="zsh"
  RC_FILE="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]]; then
  ACTIVE_SHELL="bash"
  RC_FILE="$HOME/.bashrc"
else
  ACTIVE_SHELL="unknown"
  RC_FILE=""
fi

echo "[*] Active shell: $ACTIVE_SHELL"
[[ -n "$RC_FILE" ]] && echo "[*] RC file: $RC_FILE"

########################################
# Helpers
########################################
ensure_local_bin_path() {
  [[ -z "$RC_FILE" ]] && return
  grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$RC_FILE" 2>/dev/null \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
}

ensure_nvm_init() {
  [[ -z "$RC_FILE" ]] && return

  grep -q 'export NVM_DIR="$HOME/.nvm"' "$RC_FILE" 2>/dev/null \
    || echo 'export NVM_DIR="$HOME/.nvm"' >> "$RC_FILE"

  grep -q 'nvm.sh' "$RC_FILE" 2>/dev/null || cat >> "$RC_FILE" <<'EOF'
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
}

########################################
# tmux config
########################################
TMUX_CONF_CONTENT='
set -g mouse on

set -g status-bg black
set -g status-fg white

set -g status-left "#[fg=green]#S #[fg=white]|"
set -g status-right "#[fg=yellow]%Y-%m-%d #[fg=cyan]%H:%M #[fg=white]| #[fg=magenta]#(whoami)"

set -g window-status-current-style "bg=blue,fg=white"
set -g window-status-style "bg=black,fg=white"

set -g pane-active-border-style "fg=green"
set -g pane-border-style "fg=grey"
'

########################################
# Components
########################################
COMPONENTS=(
  "system:System Update & Upgrade"
  "nvtop:nvtop GPU Monitor"
  "curl:curl"
  "uv:uv (Astral)"
  "node:Node.js (NVM + v25)"
  "codex:OpenAI Codex CLI"
  "cursor:Cursor CLI"
  "claude:Claude Code CLI"
  "tmux:tmux + custom config"
)

########################################
# Status table
########################################
echo ""
echo "Available components:"
echo "---------------------"

for c in "${COMPONENTS[@]}"; do
  key="${c%%:*}"
  label="${c#*:}"

  case "$key" in
    system) status="always available" ;;
    nvtop)  is_installed nvtop  && status="installed" || status="not installed" ;;
    curl)   is_installed curl   && status="installed" || status="not installed" ;;
    uv)     is_installed uv     && status="installed" || status="not installed" ;;
    node)   is_installed node   && status="installed" || status="not installed" ;;
    codex)  is_installed codex  && status="installed" || status="not installed" ;;
    cursor) is_installed cursor && status="installed" || status="not installed" ;;
    claude) is_installed claude && status="installed" || status="not installed" ;;
    tmux)   is_installed tmux   && status="installed" || status="not installed" ;;
  esac

  printf " - %-30s [%s]\n" "$label" "$status"
done

########################################
# Selection menu
########################################
echo ""
echo "Select components to install (space separated numbers):"
echo ""

i=1
for c in "${COMPONENTS[@]}"; do
  echo "  $i) ${c#*:}"
  ((i++))
done

echo ""
read -rp "Your choice: " -a SELECTED

########################################
# Install functions
########################################
install_system() {
  command -v apt-get >/dev/null 2>&1 || return
  $SUDO apt-get update -y
  $SUDO apt-get upgrade -y
}

install_nvtop() {
  $SUDO apt-get install -y nvtop
}

install_curl() {
  $SUDO apt-get install -y curl
}

install_uv() {
  curl -LsSf https://astral.sh/uv/install.sh | sh
  grep -q 'source "$HOME/.local/bin/env"' "$RC_FILE" 2>/dev/null \
    || echo 'source "$HOME/.local/bin/env"' >> "$RC_FILE"
  # Also load for current script session
  [ -s "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
}

install_node() {
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  nvm install 25
  ensure_nvm_init
}

install_codex() {
  npm install -g @openai/codex
}

install_cursor() {
  curl https://cursor.com/install -fsS | bash
  ensure_local_bin_path
  # Also update PATH for current script session
  export PATH="$HOME/.local/bin:$PATH"
}

install_claude() {
  curl -fsSL https://claude.ai/install.sh | bash
  ensure_local_bin_path
  # Also update PATH for current script session
  export PATH="$HOME/.local/bin:$PATH"
}

install_tmux() {
  command -v tmux >/dev/null 2>&1 || $SUDO apt-get install -y tmux

  if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d_%H%M%S)"
  fi

  printf "%s\n" "$TMUX_CONF_CONTENT" > "$HOME/.tmux.conf"
  tmux info >/dev/null 2>&1 && tmux source-file "$HOME/.tmux.conf"
}

########################################
# Execute selections
########################################
echo ""
echo "Starting installation..."
echo ""

for idx in "${SELECTED[@]}"; do
  case "$idx" in
    1) install_system ;;
    2) install_nvtop ;;
    3) install_curl ;;
    4) install_uv ;;
    5) install_node ;;
    6) install_codex ;;
    7) install_cursor ;;
    8) install_claude ;;
    9) install_tmux ;;
    *) echo "[!] Unknown selection: $idx" ;;
  esac
done

########################################
# Verify installations
########################################
echo ""
echo "[*] Infra bootstrap completed successfully."
echo ""
echo "Installation verification:"
echo "--------------------------"
for c in "${COMPONENTS[@]}"; do
  key="${c%%:*}"
  label="${c#*:}"

  case "$key" in
    system) continue ;;
    nvtop)  cmd="nvtop" ;;
    curl)   cmd="curl" ;;
    uv)     cmd="uv" ;;
    node)   cmd="node" ;;
    codex)  cmd="codex" ;;
    cursor) cmd="cursor" ;;
    claude) cmd="claude" ;;
    tmux)   cmd="tmux" ;;
  esac

  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ✓ %-25s [ready]\n" "$label"
  else
    printf "  ✗ %-25s [needs shell reload]\n" "$label"
  fi
done
echo ""

########################################
# Reload shell
########################################
if [[ -n "$RC_FILE" ]]; then
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  IMPORTANT: To use the newly installed tools, either:      ║"
  echo "║                                                            ║"
  echo "║  Option 1: Run this command now:                           ║"
  echo "║     source ~/.bashrc                                       ║"
  echo "║                                                            ║"
  echo "║  Option 2: Start a fresh shell (recommended):              ║"
  echo "║     exec bash -l                                           ║"
  echo "║                                                            ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  read -rp "Auto-reload shell now? [Y/n]: " RELOAD_CHOICE
  RELOAD_CHOICE="${RELOAD_CHOICE:-Y}"

  if [[ "$RELOAD_CHOICE" =~ ^[Yy]$ ]]; then
    echo "[*] Reloading shell..."
    exec bash -l
  fi
fi
