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

## Notes

- If no Linear MCP connector is available in the session, say so and ask the user to paste the ticket body.
- Don't dump the full ticket back at the user — they have it open. Surface only what's relevant to the task at hand.
- Sub-issues and parent links are in `get_issue` output; follow them only if the user's question spans the tree.
- Treat the ticket as source-of-truth for intent, but the code/PR as source-of-truth for current state — they often disagree.
