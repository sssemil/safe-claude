#!/usr/bin/env bash
set -euo pipefail

echo "Installing Claude Code + safe-claude"

# OS detection
OS="$(uname -s)"
case "$OS" in
  Linux|Darwin) ;;
  *) echo "error: Linux or macOS required"; exit 1 ;;
esac


# paths
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

export PATH="$BIN_DIR:$PATH"

# check if already installed
if [ -x "$BIN_DIR/safe-claude" ]; then
  echo "safe-claude is already installed."
  printf "Reinstall? [Y/n] "
  read -r answer
  case "$answer" in
    [Nn]*) echo "Aborted."; exit 0 ;;
    *) ;;
  esac
fi

# install claude code if missing
if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code (npm)"
  npm install -g @anthropic-ai/claude-code
else
  echo "Claude Code already installed"
fi

# verify claude
CLAUDE_PATH="$(command -v claude || true)"
[ -x "$CLAUDE_PATH" ] || {
  echo "error: claude install failed"
  exit 1
}

# install safe-claude
SAFE_CLAUDE="$BIN_DIR/safe-claude"

if [ "$OS" = "Linux" ]; then
  cat > "$SAFE_CLAUDE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "safe-claude: Linux required"
  exit 1
fi

if ! command -v firejail >/dev/null 2>&1; then
  echo "safe-claude: firejail not found"
  exit 1
fi

export PATH="$HOME/.local/bin:$HOME/.node/bin:$PATH"
CLAUDE="$(command -v claude || true)"
[ -x "$CLAUDE" ] || { echo "safe-claude: claude not found"; exit 1; }

PROJECT_DIR="$(pwd)"
CLAUDE_JSON="$HOME/.claude.json"
CLAUDE_DIR="$HOME/.claude"

FIREJAIL_ARGS=(
  --noprofile
  --read-only=/
  --read-only=/home
)

RW_PATHS=()

add_rw() {
  local p
  p="$(readlink -f "$1" 2>/dev/null || echo "$1")"
  FIREJAIL_ARGS+=(--noblacklist="$p" --read-write="$p")
  RW_PATHS+=("$p")
}

add_rw "$PROJECT_DIR"

[ -e "$CLAUDE_JSON" ] && add_rw "$CLAUDE_JSON"
[ -d "$CLAUDE_DIR" ]  && add_rw "$CLAUDE_DIR"
[ -d "$HOME/.cargo" ] && add_rw "$HOME/.cargo"
[ -d "$HOME/.docker" ] && add_rw "$HOME/.docker"
[ -d "$HOME/.cache" ] && add_rw "$HOME/.cache"

echo "safe-claude: writable paths:"
for p in "${RW_PATHS[@]}"; do
  echo "  RW  $p"
done

exec firejail "${FIREJAIL_ARGS[@]}" \
  "$CLAUDE" --dangerously-skip-permissions
EOF

else
  # macOS (Darwin)
  cat > "$SAFE_CLAUDE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "safe-claude: macOS required"
  exit 1
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
CLAUDE="$(command -v claude || true)"
[ -x "$CLAUDE" ] || { echo "safe-claude: claude not found"; exit 1; }

PROJECT_DIR="$(pwd -P)"
CLAUDE_DIR="$HOME/.claude"

# Generate sandbox profile with resolved paths
PROFILE="$(mktemp)"
trap "rm -f '$PROFILE'" EXIT

cat > "$PROFILE" <<SBEOF
(version 1)
(deny default)
(allow network*)
(allow process*)
(allow sysctl-read)
(allow mach-lookup)
(allow file-read*)
(allow file-ioctl)
(allow file-write* (literal "/dev/null"))
(allow file-write* (subpath "$PROJECT_DIR"))
(allow file-write* (subpath "$CLAUDE_DIR"))
(allow file-write* (subpath "$HOME/.cargo"))
(allow file-write* (subpath "$HOME/.docker"))
(allow file-write* (subpath "$HOME/.cache"))
(allow file-write* (literal "$HOME/.claude.json"))
(allow file-write* (subpath "/private/tmp"))
(allow file-write* (subpath "/private/var/folders"))
SBEOF

echo "safe-claude: writable paths:"
echo "  RW  $PROJECT_DIR"
echo "  RW  $CLAUDE_DIR"
echo "  RW  $HOME/.cargo"
echo "  RW  $HOME/.docker"
echo "  RW  $HOME/.cache"

exec sandbox-exec -f "$PROFILE" "$CLAUDE" --dangerously-skip-permissions
EOF
fi

chmod +x "$SAFE_CLAUDE"

echo
echo "Installed:"
echo "  claude       -> $(command -v claude)"
echo "  safe-claude  -> $SAFE_CLAUDE"
echo
echo "Make sure ~/.local/bin is in your PATH."
echo "Usage:"
echo "  cd your-project"
echo "  safe-claude"

