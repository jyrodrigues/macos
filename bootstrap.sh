#!/bin/sh
#
# Public bootstrap for a fresh macOS box.
#

set -eu

# ---- 1. Xcode Command Line Tools ----
# Triggers Apple's GUI installer; we wait for it to finish before continuing.
if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    printf 'Waiting for Xcode Command Line Tools install to finish'
    until xcode-select -p >/dev/null 2>&1; do
        printf '.'
        sleep 5
    done
    printf '\n'
fi

# ---- 2. Homebrew ----
if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew available in this shell (Apple Silicon vs Intel prefix).
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# ---- 3. Installing minimal dependencies ----
brew install --cask 1password
brew install just

# ---- 4. Pause for 1Password SSH agent ----
cat <<'EOF'

Open 1Password, sign in, then enable:
  Settings > Developer > Use the SSH agent
(This is what makes the SSH clone below work.)

Press ENTER when done.
EOF
# `</dev/tty` is required when this script is piped from curl — otherwise
# `read` consumes from the curl pipe and the prompt is skipped.
read _ </dev/tty

# ---- 5. Clone the setup repo ----
mkdir -p "$HOME/code/mine"
cd "$HOME/code/mine"
if [ ! -d macos-setup ]; then
    git clone git@github.com:jyrodrigues/macos-setup.git
fi
cd macos-setup

# ---- 6. Hand off ----
exec just macos-setup
