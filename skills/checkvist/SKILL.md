---
name: checkvist
description: Use when Ben asks to add, view, complete, or otherwise manage items on his personal todo list. Triggers include "add to my todos/list", "put X on my list", "what's on my list/todos", "mark X done", "what do I have to do", "checkvist". Default list is "topics" (id 619960) — use that unless he names another. ALWAYS prefix root-level items with a relevant emoji (subtasks don't need it).
---

# Checkvist todo manager

Ben's main list is **topics** — https://checkvist.com/checklists/619960. Default to it for any todo operation unless Ben names another list.

## Auth

Credentials live at `~/.claude/skills/checkvist/.credentials` (two lines, gitignored):

```
CHECKVIST_USERNAME=ben.hirsch@locally.com
CHECKVIST_OPENAPI_KEY=<from https://checkvist.com/auth/profile>
```

Bootstrap on a fresh checkout:

```bash
cp ~/.claude/skills/checkvist/.credentials.example ~/.claude/skills/checkvist/.credentials
chmod 600 ~/.claude/skills/checkvist/.credentials
# then edit and replace REPLACE_ME values
```

If `.credentials` is missing or still has `REPLACE_ME`, stop and ask Ben to populate it. **Never echo or commit the OpenAPI key.**

The CLI exchanges these for a session token via `POST /auth/login.json` and caches it at `~/.claude/.cache/checkvist_token.json` (chmod 600). Token is reused until a 401 forces a re-auth.

## CLI

`~/.claude/skills/checkvist/checkvist.py` — stdlib-only Python, no deps. All operations default to list 619960; use `--list <id>` to target another.

| Verb | Example |
|---|---|
| Add a root task | `checkvist.py add "🚀 Ship the thing"` |
| Add a subtask | `checkvist.py add "draft section X" --parent 12345` |
| List all tasks | `checkvist.py list` |
| Find by content | `checkvist.py find "VDR"` |
| Mark complete | `checkvist.py complete 12345` |
| Show all lists | `checkvist.py lists` |

## Rules

1. **Emoji prefix on every root-level item.** First character of every top-level (non-subtask) task content must be an emoji that visually represents the category. Subtasks (`--parent <id>`) don't need one.
2. **Default list = 619960 ("topics").** Only change if Ben explicitly names another list.
3. **Confirm before bulk adds.** If you're about to add more than 5 items in one go, show Ben the full list first and wait for "go."
4. **Don't auto-complete tasks** unless Ben explicitly says to mark something done. Status changes are sticky.
