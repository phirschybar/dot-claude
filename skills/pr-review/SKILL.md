---
name: pr-review
description: Use whenever the user asks for a PR code review (e.g. "review this PR", "/review <url>", "can you look at #1234"). Produces a PENDING GitHub review with major concerns as inline comments and secondary feedback in the body. Everything stays in draft until the user submits manually.
---

# PR review (pending, with inline comments)

Creates a pending review on a GitHub PR — major concerns anchored as inline line comments, overview/nits/risk summary in the body. User submits manually from the GH UI.

## Steps

1. **Identify the PR.** URL or number from the user. If neither, run `gh pr list --repo <owner/repo>` and ask which.

2. **Fetch context.**
   - `gh pr view <num> --repo <owner/repo> --json title,body,author,baseRefName,files,additions,deletions,url` (plain `gh pr view` can 500 on "Projects classic" — always use `--json`).
   - `gh api /repos/<owner>/<repo>/pulls/<num>/files` — returns `patch` per file. The `position` field (1-indexed offset into the unified diff) is the fallback if `line` anchoring fails.
   - Large diffs: save `gh pr diff <num>` to a file rather than reading into context.

3. **Analyze.** Prioritize:
   - Behavior changes outside the PR's stated scope (easiest to miss, highest impact)
   - Correctness, security, injection
   - Duplicated logic / inconsistent implementations across files
   - Test hacks that paper over real bugs
   - Style/naming nits (usually → body, not inline)

4. **Split feedback.**
   - **Inline (4–6 max)**: anchored to a specific line — bugs, risky changes, per-line nits.
   - **Body**: overview, overall risk summary, multi-line nits, things you liked.

5. **Map each inline concern to a diff line.** From the `patch` for that file, pick a `+` line (or `-` if commenting on deleted code). Use:
   - `path`: repo-relative
   - `line`: line in new file (for `+`) or old file (for `-`)
   - `side`: `"RIGHT"` (new) or `"LEFT"` (old)
   - `body`: markdown

6. **Create the pending review in ONE POST.** Write the payload to `/tmp/pr-review-payload.json` to avoid shell escaping:
   ```json
   {
     "body": "...",
     "comments": [
       {"path": "...", "line": N, "side": "RIGHT", "body": "..."}
     ]
   }
   ```
   Then: `gh api -X POST /repos/<owner>/<repo>/pulls/<num>/reviews --input /tmp/pr-review-payload.json`

   **Do NOT include an `event` field** — omitting it keeps state `PENDING`.

7. **Verify.** `gh api /repos/.../reviews/<id> --jq '{state, submitted_at}'` → expect `PENDING`, `submitted_at: null`.

8. **Report back.** In your message to the user, include:
   - The review URL.
   - **The full review body, verbatim, in a fenced ` ```markdown ` block** so they can copy-paste straight into the GH submit modal. (See the ⚠️ below for why — the API-set body does not pre-populate the modal textarea.)
   - A short lead-in sentence above the fenced block like: *"Paste this into the 'Leave a comment' textarea in the Finish-your-review modal before submitting, otherwise the body will be lost."*
   - A brief plain-English summary of the review (a few sentences, not the full body) so the thread stays readable.

## ⚠️ Why the body needs to be posted back in chat

When the user clicks "Finish your review → Submit" in the GH UI, the modal opens with an **empty body textarea** — it does NOT pre-populate from the API-set body. Whatever's in the textarea at submit becomes the body; an empty textarea overwrites the API-set body with empty.

Posting the body in the chat thread as a fenced markdown block lets the user copy it directly from the Claude UI into the modal, instead of having to open the pending review → Edit → copy from there.

Inline comments submit correctly regardless — only the body has this quirk.

Alternative (offer if the body is short / mostly risk-summary fluff): move everything to inline comments and submit with an intentionally empty body.

## Notes

- A pending review is only visible to its author. Safe to create, delete, or recreate freely.
- Delete with `gh api -X DELETE /repos/.../reviews/<id>` if the user wants to restart.
- Pending-review `GET` endpoints return `line: null` / `side: null` on their comments — that's a display quirk, the anchors are real (verify via `position` / `original_position`).
- Don't use `gh pr review` CLI — it doesn't support pending state; the API is the only path for drafts.
