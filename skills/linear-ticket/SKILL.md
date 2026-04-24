---
name: linear-ticket
description: Use whenever the user references a Linear ticket — either a full URL like `https://linear.app/<org>/issue/FRG-252/...` or a bare ticket ID like `FRG-252`. Fetches the issue via the Linear MCP connector and reads the overview, comment thread, and any linked PRs/branches before acting on the user's request.
---

# Linear ticket fetch

When the user mentions a Linear ticket, pull it from the Linear MCP connector before responding. Don't infer content from the URL slug — the slug is lossy and often stale.

## Recognizing a reference

- Full URL: `https://linear.app/<org>/issue/<TEAM>-<N>/<slug>` → identifier is `<TEAM>-<N>` (e.g. `FRG-252`).
- Bare ID in-message: `FRG-252`, `ENG-41`, etc. (uppercase team prefix + `-` + number).
- Phrases like "the FRG-252 ticket" or "look at FRG-252" count.

If the ID is ambiguous (could be a file path, commit, etc.), ask before fetching.

## Steps

1. **Fetch the issue.** Call the Linear MCP `get_issue` tool (actual name is `mcp__<server>__get_issue` — the `<server>` segment depends on how the connector is registered; use whichever `get_issue` the Linear connector exposes). Pass the identifier (`FRG-252`), not the URL.

2. **Read the overview.** Title, state, assignee, priority, labels, cycle/project, and the full description. The description usually carries the real requirements — read it, don't skim.

3. **Fetch the comment thread.** `list_comments` with the issue ID. Decisions, scope changes, and gotchas tend to live here rather than in the description. Read chronologically.

4. **Glance at linked PRs and branches.** The issue's `attachments` (or the `list_attachments` tool) surfaces git integrations — GitHub PR URLs, branch names, etc. For each:
   - Note the PR number, state (open/merged/closed), and title.
   - Fetch full PR details with `gh pr view <N> --repo <owner>/<repo>` only if the user's task requires it (e.g. they asked for a review, or to continue the work).
   - A branch attachment without a PR usually means the work is mid-flight — worth mentioning.

5. **Then do what the user asked.** The fetch is context-gathering, not the deliverable. Proceed to the actual task (summarize, implement, review, estimate, etc.).

## Keeping the description in sync with progress

Once a Linear ticket has been referenced in the session, treat its **description** as a living progress log for as long as the session is working on that ticket. The user wants to open the ticket at any time and see where things stand — without asking.

**Write to the description, never to comments.** Comments create noise and notifications; the description is the single source of truth the user will check.

**When to update:**
- After completing a meaningful step (investigation finished, plan agreed, code change landed, PR opened, blocker hit, decision made).
- When scope or approach changes.
- Not on every tool call. If nothing material has changed since the last update, don't write.

**How to update:**
1. Re-fetch the issue with `get_issue` to get the current description (it may have been edited since you last saw it).
2. Preserve the original description content. Append or maintain a dedicated progress section at the bottom, clearly delimited — e.g.:
   ```
   ---
   ## Progress (auto-updated by Claude)
   _Last updated: <ISO date>_

   - [x] Investigated auth middleware — confirmed root cause is X
   - [x] PR opened: #1234
   - [ ] Awaiting review from @alice
   - **Blockers:** none
   ```
3. Call `save_issue` with the issue ID and the new full description. Do not omit the original body.
4. Keep it scannable — bullets, short lines, current status first. This is for the user's glance, not a changelog.

If multiple Linear tickets come up in one session, maintain this for each.

## Notes

- If no Linear MCP connector is available in the session, say so and ask the user to paste the ticket body.
- Don't dump the full ticket back at the user — they have it open. Surface only what's relevant to the task at hand.
- Sub-issues and parent links are in `get_issue` output; follow them only if the user's question spans the tree.
- Treat the ticket as source-of-truth for intent, but the code/PR as source-of-truth for current state — they often disagree.
