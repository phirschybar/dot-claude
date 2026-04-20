# dot-claude

Version-controlled subset of `~/.claude/` — the portable, user-level configuration for [Claude Code](https://claude.com/claude-code).

## What's tracked

A deny-by-default `.gitignore` allowlists only:

- `skills/` — custom skills
- `agents/` — custom subagents
- `commands/` — custom slash commands
- `hooks/` — shell hooks wired up via settings
- `output-styles/` — response style customizations
- `settings.json` — shared settings
- `keybindings.json` — keyboard customizations
- `CLAUDE.md` — user-level instructions

Ephemeral/local/sensitive state stays out: sessions, caches, projects, credentials, `settings.local.json`, file history, plans, shell snapshots, etc.

## Skills

- `pr-review` — produces a PENDING GitHub PR review with inline comments and a body summary; user submits manually from the GH UI.
- `linear-ticket` — on any Linear URL or bare ticket ID (e.g. `FRG-252`), fetches the issue via the Linear MCP connector (overview, comment thread, linked PRs/branches) before acting on the request. Requires the `claude.ai Linear` connector to be connected on the account (connector is managed via claude.ai, not tracked in this repo).
- `outline-docs` — read, search, create, or update pages in the company Outline knowledge base at `documentation.locally.com` via the Outline REST API. Requires a personal API token at `skills/outline-docs/.api-key` (gitignored; bootstrap from `.api-key.example`).

## Setup on a new machine

```sh
# If ~/.claude/ does not exist yet
git clone https://github.com/phirschybar/dot-claude.git ~/.claude

# If ~/.claude/ exists and you want to adopt the repo in place
cd ~/.claude
git init -b main
git remote add origin https://github.com/phirschybar/dot-claude.git
git fetch
git reset origin/main   # keep local files; just adopt git history

# Tracked files from the repo that don't yet exist locally will show as
# "deleted" (present in index, missing from working tree). Restore them:
git restore .
```

## Adding new skills / agents / commands

Drop a file in the matching directory and commit it. The `.gitignore` already allowlists those paths, so `git status` will pick them up automatically.

```sh
# Example: a new skill
mkdir -p ~/.claude/skills/my-new-skill
$EDITOR ~/.claude/skills/my-new-skill/SKILL.md
cd ~/.claude && git add skills/my-new-skill && git commit -m "Add my-new-skill"
```

Claude Code discovers new skills at session start — restart any running session to pick them up.

## Tracking a new top-level path

If Claude Code ever adds a new portable config path not in the allowlist, extend `.gitignore`:

```gitignore
!/new-path/
```

Then `git add` the new directory.
