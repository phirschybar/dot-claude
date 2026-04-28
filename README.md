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
- `laradock-worktree` — point the local laradock dev environment (`~/Locally/laradock`) at a different code path (typically a worktree at `~/Locally/.claude/worktrees/...`), copy the env/vendor/compiled assets the bind-mounted containers expect, and recreate nginx + php-fpm + workspace so the new mount takes. Triggered by phrases like "switch laradock to X" or "preview this branch in the browser".
- `checkvist` — manage a personal Checkvist todo list. Defaults to a single configured list. Stdlib-only Python CLI exposing `add`, `list`, `find`, `complete`, `lists`. Requires credentials at `skills/checkvist/.credentials` (gitignored; bootstrap from `.credentials.example`). Auto-prefixes root-level items with an emoji per the configured convention.

Per-skill secrets live alongside the skill (gitignored): `skills/<skill>/.api-key` for single-token APIs, `skills/<skill>/.credentials` for multi-value (username + key). Both patterns are blocked at the repo root in `.gitignore`.

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
