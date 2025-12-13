# safe-claude

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a sandbox with a read-only filesystem.

## Install

```bash
curl -fsSL safe-claude.com/install.sh | bash
```

## Usage

```bash
cd your-project
safe-claude
```

Only the current directory and Claude config files are writable. Everything else is read-only.

## Requirements

- Linux or macOS
- Linux: [firejail](https://firejail.wordpress.com/)
- macOS: sandbox-exec (built-in)
- Node.js + npm

## License

MIT
