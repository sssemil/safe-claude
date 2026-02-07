# safe-claude

Run AI coding agents in a sandbox with a read-only filesystem.

## Install

```bash
curl -fsSL safe-claude.com/install.sh | bash
```

## Usage

```bash
cd your-project
safe-claude
safe-codex
safe-opencode
```

Only the current directory and supported agent config files are writable. Everything else is read-only.
safe-opencode sets `OPENCODE_PERMISSION` to allow all permissions.

## Requirements

- Linux or macOS
- Linux: [firejail](https://firejail.wordpress.com/)
- macOS: sandbox-exec (built-in)
- Node.js + npm

## License

MIT
