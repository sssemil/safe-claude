#!/usr/bin/env bash
set -euo pipefail

echo "Installing safe-claude, safe-codex, safe-opencode, and safe"

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
if [ -x "$BIN_DIR/safe-claude" ] || [ -x "$BIN_DIR/safe-codex" ] || [ -x "$BIN_DIR/safe-opencode" ] || [ -x "$BIN_DIR/safe" ]; then
  echo "safe-* scripts already installed."
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

# install generic safe command (base for all wrappers)
SAFE_CMD="$BIN_DIR/safe"

if [ "$OS" = "Linux" ]; then
  cat > "$SAFE_CMD" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "safe: Linux required"
  exit 1
fi

if ! command -v firejail >/dev/null 2>&1; then
  echo "safe: firejail not found"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "Usage: safe <command> [args...]"
  echo "Run a command in a sandboxed environment with write access only to current directory."
  exit 1
fi

PROJECT_DIR="$(pwd)"

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

[ -d "$HOME/.claude" ] && add_rw "$HOME/.claude"
[ -f "$HOME/.claude.json" ] && add_rw "$HOME/.claude.json"
[ -d "$HOME/.codex" ] && add_rw "$HOME/.codex"
[ -d "$HOME/.openai" ] && add_rw "$HOME/.openai"
[ -d "$HOME/.config/opencode" ] && add_rw "$HOME/.config/opencode"
[ -d "$HOME/.opencode" ] && add_rw "$HOME/.opencode"
[ -n "${OPENCODE_CONFIG_DIR:-}" ] && [ -d "$OPENCODE_CONFIG_DIR" ] && add_rw "$OPENCODE_CONFIG_DIR"
[ -n "${OPENCODE_CONFIG:-}" ] && [ -f "$OPENCODE_CONFIG" ] && add_rw "$OPENCODE_CONFIG"
[ -d "$HOME/.cargo" ] && add_rw "$HOME/.cargo"
[ -d "$HOME/.docker" ] && add_rw "$HOME/.docker"
[ -d "$HOME/.cache" ] && add_rw "$HOME/.cache"
[ -d "$HOME/.npm" ] && add_rw "$HOME/.npm"
[ -d "$HOME/.gradle" ] && add_rw "$HOME/.gradle"
[ -d "$HOME/.conda" ] && add_rw "$HOME/.conda"

echo "safe: writable paths:"
for p in "${RW_PATHS[@]}"; do
  echo "  RW  $p"
done

exec firejail "${FIREJAIL_ARGS[@]}" "$@"
EOF

else
  # macOS (Darwin)
  cat > "$SAFE_CMD" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "safe: macOS required"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "Usage: safe <command> [args...]"
  echo "Run a command in a sandboxed environment with write access only to current directory."
  exit 1
fi

PROJECT_DIR="$(pwd -P)"

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
(allow file-write* (subpath "$HOME/.claude"))
(allow file-write* (literal "$HOME/.claude.json"))
(allow file-write* (subpath "$HOME/.codex"))
(allow file-write* (subpath "$HOME/.openai"))
(allow file-write* (subpath "$HOME/.cargo"))
(allow file-write* (subpath "$HOME/.docker"))
(allow file-write* (subpath "$HOME/.cache"))
(allow file-write* (subpath "$HOME/.npm"))
(allow file-write* (subpath "$HOME/.gradle"))
(allow file-write* (subpath "$HOME/.conda"))
(allow file-write* (subpath "/private/tmp"))
(allow file-write* (subpath "/private/var/folders"))
SBEOF

if [ -d "$HOME/.config/opencode" ]; then
  echo "(allow file-write* (subpath \"$HOME/.config/opencode\"))" >> "$PROFILE"
fi
if [ -d "$HOME/.opencode" ]; then
  echo "(allow file-write* (subpath \"$HOME/.opencode\"))" >> "$PROFILE"
fi
if [ -n "${OPENCODE_CONFIG:-}" ] && [ -f "$OPENCODE_CONFIG" ]; then
  echo "(allow file-write* (literal \"$OPENCODE_CONFIG\"))" >> "$PROFILE"
fi
if [ -n "${OPENCODE_CONFIG_DIR:-}" ] && [ -d "$OPENCODE_CONFIG_DIR" ]; then
  echo "(allow file-write* (subpath \"$OPENCODE_CONFIG_DIR\"))" >> "$PROFILE"
fi

echo "safe: writable paths:"
echo "  RW  $PROJECT_DIR"
[ -d "$HOME/.claude" ] && echo "  RW  $HOME/.claude"
[ -f "$HOME/.claude.json" ] && echo "  RW  $HOME/.claude.json"
[ -d "$HOME/.codex" ] && echo "  RW  $HOME/.codex"
[ -d "$HOME/.openai" ] && echo "  RW  $HOME/.openai"
[ -d "$HOME/.config/opencode" ] && echo "  RW  $HOME/.config/opencode"
[ -d "$HOME/.opencode" ] && echo "  RW  $HOME/.opencode"
[ -n "${OPENCODE_CONFIG:-}" ] && [ -f "$OPENCODE_CONFIG" ] && echo "  RW  $OPENCODE_CONFIG"
[ -n "${OPENCODE_CONFIG_DIR:-}" ] && [ -d "$OPENCODE_CONFIG_DIR" ] && echo "  RW  $OPENCODE_CONFIG_DIR"
echo "  RW  $HOME/.cargo"
echo "  RW  $HOME/.docker"
echo "  RW  $HOME/.cache"
echo "  RW  $HOME/.npm"
echo "  RW  $HOME/.gradle"
echo "  RW  $HOME/.conda"

exec sandbox-exec -f "$PROFILE" "$@"
EOF
fi

chmod +x "$SAFE_CMD"

# install safe-claude (thin wrapper around safe)
SAFE_CLAUDE="$BIN_DIR/safe-claude"
cat > "$SAFE_CLAUDE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SAFE="$(dirname "$0")/safe"
exec "$SAFE" claude --dangerously-skip-permissions "$@"
EOF
chmod +x "$SAFE_CLAUDE"

# install safe-codex (thin wrapper around safe)
SAFE_CODEX="$BIN_DIR/safe-codex"
cat > "$SAFE_CODEX" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SAFE="$(dirname "$0")/safe"
exec "$SAFE" codex --dangerously-bypass-approvals-and-sandbox "$@"
EOF
chmod +x "$SAFE_CODEX"

# install safe-opencode (thin wrapper around safe)
SAFE_OPENCODE="$BIN_DIR/safe-opencode"
cat > "$SAFE_OPENCODE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SAFE="$(dirname "$0")/safe"
OPENCODE_PERMISSION='{"*":"allow"}'
export OPENCODE_PERMISSION
exec "$SAFE" opencode "$@"
EOF
chmod +x "$SAFE_OPENCODE"

echo
echo "Installed:"
echo "  safe-claude  -> $SAFE_CLAUDE"
echo "  safe-codex   -> $SAFE_CODEX"
echo "  safe-opencode -> $SAFE_OPENCODE"
echo "  safe         -> $SAFE_CMD"
echo
echo "Make sure ~/.local/bin is in your PATH."
echo
echo "Usage:"
echo "  safe-claude              # Run Claude Code in sandbox"
echo "  safe-codex               # Run Codex CLI in sandbox"
echo "  safe-opencode            # Run OpenCode in sandbox"
echo "  safe <command> [args]    # Run any command in sandbox"
