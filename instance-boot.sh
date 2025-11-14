#!/usr/bin/env bash
set -euo pipefail

echo "[*] RentGPU minimal bootstrap starting..."

########################################
# 0. Detect sudo availability
########################################
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "[*] Running as root. sudo not required."
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  echo "[*] sudo detected. Using sudo."
  SUDO="sudo"
else
  echo "[!] Not root and no sudo available."
  echo "    System package installation may not work."
  SUDO=""
fi

########################################
# 1. System update & upgrade
########################################
if command -v apt-get >/dev/null 2>&1; then
  echo "[*] Updating system packages..."
  $SUDO apt-get update -y || true
  $SUDO apt-get upgrade -y || true
else
  echo "[!] apt-get not found. Skipping package installation."
fi

########################################
# 2. Install nvtop and curl (if possible)
########################################
if command -v apt-get >/dev/null 2>&1; then
  echo "[*] Installing nvtop and curl..."
  $SUDO apt-get install -y nvtop curl || echo "[!] Failed to install nvtop (not critical)."
else
  echo "[!] apt-get missing. Skipping nvtop installation."
fi

########################################
# 3. SSH environment preparation
########################################
echo "[*] Setting up ~/.ssh directory..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add GitHub to known_hosts (prevents yes/no prompt)
if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
  echo "[*] Adding github.com to known_hosts..."
  ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true
fi
chmod 644 ~/.ssh/known_hosts || true

# Check if the master SSH key exists
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  echo ""
  echo "[!] No SSH master key found."
  echo "    You must copy your master key from your Mac:"
  echo "    scp ~/.ssh/rentgpu_master ~/.ssh/rentgpu_master.pub root@IP:~/.ssh/"
  echo ""
else
  echo "[*] SSH key found. GitHub authentication should work."
fi

########################################
# 4. Install uv
########################################
if ! command -v uv >/dev/null 2>&1; then
  echo "[*] Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || echo "[!] uv installation failed."
else
  echo "[*] uv already installed."
fi

########################################
# 5. Install Node.js (NVM + Node 25)
########################################
echo "[*] Installing NVM + Node.js v25..."

# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash || {
  echo "[!] NVM installation failed."
}

# Load NVM without restarting shell
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  . "$HOME/.nvm/nvm.sh"
fi

# Install Node 25 using NVM
if command -v nvm >/dev/null 2>&1; then
  nvm install 25 || echo "[!] Failed to install Node.js v25"
else
  echo "[!] NVM not loaded. Node.js installation skipped."
fi

########################################
# 6. Install Codex CLI
########################################
if command -v npm >/dev/null 2>&1; then
  echo "[*] Installing OpenAI Codex CLI..."
  npm install -g @openai/codex || echo "[!] Failed to install Codex CLI."
else
  echo "[!] npm not found. Skipping Codex CLI."
fi

########################################
# 7. Install Cursor CLI
########################################
echo "[*] Installing Cursor CLI..."
curl https://cursor.com/install -fsS | bash || echo "[!] Failed to install Cursor CLI."

echo "[*] Bootstrap completed."
echo "[*] If you just copied your SSH key, you may need to restart your terminal."
