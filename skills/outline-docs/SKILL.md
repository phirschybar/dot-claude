---
name: outline-docs
description: Use when the user asks to read, search, create, or update a page in the company Outline knowledge base at https://documentation.locally.com (e.g. "grab the runbook from Outline", "post this to our docs", "search Outline for X"). Hits the Outline REST API with a stored API token; does not attempt browser scraping.
---

# Outline Documentation (documentation.locally.com)

Outline is the company's self-hosted knowledge base. API docs: https://www.getoutline.com/developers. All endpoints are `POST` with a JSON body, even for reads.

## Auth

- Base URL: `https://documentation.locally.com/api`
- Token lives at `~/.claude/skills/outline-docs/.api-key` (single line, no newline, no prefix). This file is gitignored. On a fresh checkout bootstrap it with:
  ```bash
  cp ~/.claude/skills/outline-docs/.api-key.example ~/.claude/skills/outline-docs/.api-key
  chmod 600 ~/.claude/skills/outline-docs/.api-key
  # then edit and replace REPLACE_ME with the real token
  ```
- Load it at invocation time — don't paste it into command strings:
  ```bash
  TOKEN=$(cat ~/.claude/skills/outline-docs/.api-key)
  curl -sS -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
       -X POST https://documentation.locally.com/api/documents.info \
       -d '{"id":"<doc-id-or-url-slug>"}'
  ```
- The token is a secret. Never echo it, never write it into a file you edit, never include it in a URL or a PR/commit. If the file is missing or contains `REPLACE_ME`, stop and ask the user to populate it.

## Identifying a document

A user reference can be any of:
- A full URL like `https://documentation.locally.com/doc/runbook-abcDEF123` → the trailing slug-with-id is accepted directly as `id`.
- A UUID.
- A title — resolve via `documents.search` first, then operate on the returned `id`.

## Common operations

All responses are JSON with a top-level `data` field. Pipe through `jq` to pull what you need.

| Intent | Endpoint | Key body fields |
|---|---|---|
| Search | `documents.search` | `query`, optional `collectionId`, `limit` |
| Read one doc | `documents.info` | `id` (UUID or url-slug-with-id) |
| List a collection | `documents.list` | `collectionId`, `limit`, `offset` |
| List collections | `collections.list` | `limit`, `offset` |
| Create | `documents.create` | `title`, `text` (markdown), `collectionId`, optional `parentDocumentId`, `publish: true` |
| Update | `documents.update` | `id`, `title`, `text`, `append: false`, `publish: true` |
| Append to a doc | `documents.update` | `id`, `text`, `append: true` |

Outline stores document bodies as markdown — write and read `text` as markdown, not HTML.

## Writing (create / update) — be careful

Writes are visible to the whole company. Before you call `documents.create` or a non-append `documents.update`:

1. Show the user the title, target collection (and parent doc if any), and the full body you plan to send.
2. Get explicit confirmation.
3. Then POST.

For updates, prefer `"append": true` when the user wants to add a section — it's non-destructive. A full update with `append: false` replaces the body; always diff against the existing `text` from `documents.info` and show the user what will change.

## Tips

- `documents.search` returns `ranking` and a `context` snippet — use the snippet to decide which hit is right before fetching the full doc.
- `documents.info` accepts either the UUID or the `url-slug-abcDEF123` form. For a URL the user pastes, strip everything up to `/doc/` and pass the rest.
- Rate limits: the API is generous but not unlimited. Don't loop over `documents.list` to grab every doc in a collection unless the user specifically asked for that.
- If a request returns `{"ok": false, "error": "authentication_required"}` or 401, the token is wrong or expired — surface the error, don't retry.
- For large bodies, write the JSON payload to `/tmp/outline-payload.json` and use `curl --data-binary @/tmp/outline-payload.json` to avoid shell quoting hell.
