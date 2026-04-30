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

# ---- 3. just (direct from GitHub releases) ----
# Bypassing Homebrew: on unsupported macOS (Tier 3) brew has no bottle and falls
# back to compiling rust + llvm from source — multi-hour build that may fail.
echo "---- just ----"
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
if command -v just >/dev/null 2>&1; then
    echo "Already installed"
else (
    case "$(uname -m)" in
        arm64)  target=aarch64-apple-darwin ;;
        x86_64) target=x86_64-apple-darwin ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    # https://github.com/casey/just/releases — only tarballs ship, version is in
    # the filename, so we discover the latest tag via the /releases/latest
    # redirect Location header (no `gh` available yet at bootstrap time).
    tag=$(curl -fsSI https://github.com/casey/just/releases/latest \
        | awk 'BEGIN{IGNORECASE=1} /^location:/ {n=split($2,a,"/"); print a[n]}' \
        | tr -d '\r')
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    curl -L --silent --output "$tmp/just.tar.gz" \
        "https://github.com/casey/just/releases/download/${tag}/just-${tag}-${target}.tar.gz"
    tar -xzf "$tmp/just.tar.gz" -C "$tmp"
    cp "$tmp/just" "$HOME/.local/bin/just"
) fi

# ---- 4. 1Password (direct from downloads.1password.com) ----
echo "---- 1Password ----"
if [ -d /Applications/1Password.app ]; then
    echo "Already installed"
else (
    # `1Password-latest.zip` is the full universal app bundle (~210MB). The
    # similarly-named `1Password.zip` is a stub bootstrapper that downloads the
    # real app on first launch — wrong for headless install.
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    curl -L --silent --output "$tmp/1Password.zip" \
        "https://downloads.1password.com/mac/1Password-latest.zip"
    unzip -q "$tmp/1Password.zip" -d "$tmp"
    cp -R "$tmp/1Password.app" /Applications/
    xattr -dr com.apple.quarantine /Applications/1Password.app 2>/dev/null || true
) fi

# ---- 5. Pause for 1Password SSH agent ----
cat <<'EOF'

Open 1Password, sign in, then enable:
  Settings > Developer > Use the SSH agent
(This is what makes the SSH clone below work.)

Press ENTER when done.
EOF
read _

# ---- 6. Clone the setup repo ----
mkdir -p "$HOME/code/mine"
cd "$HOME/code/mine"
if [ ! -d macos-setup ]; then
    git clone git@github.com:jyrodrigues/macos-setup.git
fi
cd macos-setup

# ---- 7. Hand off ----
exec just full-setup
