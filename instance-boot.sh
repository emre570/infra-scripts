#!/usr/bin/env bash
set -uo pipefail

# Exit on error, but allow individual install steps to fail gracefully
FAILED=()

echo "[*] Infra bootstrap starting..."

########################################
# Utils
########################################
is_installed() {
  command -v "$1" >/dev/null 2>&1
}

run_step() {
  local label="$1"
  shift
  echo ""
  echo "========================================"
  echo "[*] Installing: $label"
  echo "========================================"
  if "$@"; then
    echo "[+] $label — done"
  else
    echo "[!] $label — FAILED"
    FAILED+=("$label")
  fi
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
  export PATH="$HOME/.local/bin:$PATH"
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
# Install functions
########################################
install_system() {
  command -v apt-get >/dev/null 2>&1 || return 0
  $SUDO apt-get update -y
  $SUDO apt-get upgrade -y
}

install_nvtop() {
  is_installed nvtop && { echo "[*] nvtop already installed, skipping"; return 0; }
  $SUDO apt-get install -y nvtop
}

install_curl() {
  is_installed curl && { echo "[*] curl already installed, skipping"; return 0; }
  $SUDO apt-get install -y curl
}

install_uv() {
  is_installed uv && { echo "[*] uv already installed, skipping"; return 0; }
  curl -LsSf https://astral.sh/uv/install.sh | sh
  if [[ -n "$RC_FILE" ]]; then
    grep -q 'source "$HOME/.local/bin/env"' "$RC_FILE" 2>/dev/null \
      || echo 'source "$HOME/.local/bin/env"' >> "$RC_FILE"
  fi
  [ -s "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
}

install_node() {
  if is_installed node; then
    echo "[*] Node.js already installed, skipping"
    return 0
  fi
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  nvm install 25
  ensure_nvm_init
}

install_codex() {
  is_installed codex && { echo "[*] codex already installed, skipping"; return 0; }
  # Ensure nvm/node are available in this session
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  npm install -g @openai/codex
}

install_cursor() {
  is_installed cursor && { echo "[*] cursor already installed, skipping"; return 0; }
  curl https://cursor.com/install -fsS | bash
  ensure_local_bin_path
}

install_claude() {
  is_installed claude && { echo "[*] claude already installed, skipping"; return 0; }
  curl -fsSL https://claude.ai/install.sh | bash
  ensure_local_bin_path
}

install_tmux() {
  is_installed tmux || $SUDO apt-get install -y tmux

  if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d_%H%M%S)"
  fi

  printf "%s\n" "$TMUX_CONF_CONTENT" > "$HOME/.tmux.conf"
  tmux info >/dev/null 2>&1 && tmux source-file "$HOME/.tmux.conf" || true
}

########################################
# Install everything in dependency order
########################################

# 1. System update (apt cache must be fresh before any apt-get install)
run_step "System Update & Upgrade" install_system

# 2. Basic tools from apt (needed by later steps)
run_step "curl"               install_curl
run_step "nvtop GPU Monitor"  install_nvtop
run_step "tmux + custom config" install_tmux

# 3. Tools installed via curl (need curl)
run_step "uv (Astral)"       install_uv
run_step "Node.js (NVM + v25)" install_node

# 4. Tools installed via npm (need node)
run_step "OpenAI Codex CLI"  install_codex

# 5. Standalone CLI installers (need curl + PATH setup)
run_step "Cursor CLI"        install_cursor
run_step "Claude Code CLI"   install_claude

########################################
# Verify installations
########################################
CHECKS=(
  "nvtop:nvtop GPU Monitor"
  "curl:curl"
  "uv:uv (Astral)"
  "node:Node.js (NVM + v25)"
  "codex:OpenAI Codex CLI"
  "cursor:Cursor CLI"
  "claude:Claude Code CLI"
  "tmux:tmux + custom config"
)

echo ""
echo "[*] Infra bootstrap completed."
echo ""
echo "Installation verification:"
echo "--------------------------"
for c in "${CHECKS[@]}"; do
  cmd="${c%%:*}"
  label="${c#*:}"

  if is_installed "$cmd"; then
    printf "  ✓ %-25s [ready]\n" "$label"
  else
    printf "  ✗ %-25s [needs shell reload]\n" "$label"
  fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "[!] The following steps failed:"
  for f in "${FAILED[@]}"; do
    echo "    - $f"
  done
fi

echo ""
if [[ -n "$RC_FILE" ]]; then
  echo "[*] Run 'exec bash -l' or open a new terminal to pick up all PATH changes."
fi
