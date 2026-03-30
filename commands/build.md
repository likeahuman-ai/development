---
description: "Implement GitHub Issue tickets sequentially with subagent execution, lightweight review, and PR creation"
argument-hint: "Milestone, version label, or issue numbers (e.g. 'v4', '#203 #204 #205')"
---

# /build — Ticket Implementation

You are implementing GitHub Issue tickets. You read tickets, sequence them via a build-planner agent, implement them sequentially with subagents, run lightweight review after each ticket, and create PRs optimized for AI review.

You are mostly autonomous — one approval gate (build order) then continuous execution until done.

**Initial request:** $ARGUMENTS

---

## Phase 1: Build Order

**Goal:** Fetch tickets and determine implementation sequence.

### 1. Identify tickets

Determine the GitHub repository from `git remote -v`. Use the `gh` CLI for all GitHub operations.

Based on `$ARGUMENTS`:
- **Version label** (e.g. "v4") → `gh issue list --label v4 --state open --json number,title,body,labels`
- **Milestone** → `gh issue list --milestone "..." --state open --json number,title,body,labels`
- **Issue numbers** (e.g. "#203 #204 #205") → fetch each with `gh issue view`
- **Empty** → ask the user what to build

### 2. Dispatch build-planner

Launch a `build-planner` agent (sonnet) with clean context. Provide only:
- Ticket numbers, titles, full body content
- Dependency links (from issue body "Blocked by" / "Blocks" sections)
- Priority labels, complexity labels

The build-planner returns: ordered sequence, grouping recommendations, PR split suggestions, flags.

### 3. Present build order

Show the user the proposed sequence:

```
## Build Order: [label/milestone] ([N] tickets)

1. #203 — [title] [S] blocker — [one-line reason]
2. #204 — [title] [M] blocker — [one-line reason]
3. #205 — [title] [S] important — [one-line reason]
...

PR boundaries: #203-#205 (~350 lines), #206-#208 (~400 lines)
```

**Gate:** User approves or adjusts the build order. Ask: "Ready to build? Any changes to the order?"

---

## Phase 2: Execute

**Goal:** Implement each ticket sequentially with subagent execution and lightweight review.

For each ticket in the approved build order, execute this loop:

### Step 1: Dispatch implementer

Launch an implementer agent in a worktree. Select model based on ticket complexity:
- **S** (small) → sonnet
- **M** (medium) → sonnet
- **L** (large) → inherit (Opus)

Use the prompt template from `references/implementer-prompt.md`. Fill in ticket content, sequence position, and prior ticket titles.

### Step 2: Handle implementer result

- **DONE** → proceed to review
- **DONE_WITH_CONCERNS** → read the concerns, assess whether they matter, then proceed to review
- **NEEDS_CONTEXT** → provide the missing context from your knowledge of the PRD/codebase, re-dispatch the implementer with the same model
- **BLOCKED** → assess the blocker:
  1. Can you provide more context? → re-dispatch with context
  2. Would a more capable model help? → re-dispatch with inherit (Opus)
  3. Should the ticket be broken down? → tell the user
  4. Is it a real blocker? → escalate to the user

### Step 3: Lightweight spec review

Dispatch a spec reviewer agent (sonnet). Use the prompt template from `references/spec-reviewer-prompt.md`. Paste the ticket spec and implementer report.

### Step 4: Lightweight quality review

Only if spec review passed. Dispatch a quality reviewer agent (sonnet). Use the prompt template from `references/quality-reviewer-prompt.md`. Paste the ticket description and changed files.

### Step 5: Fix loop (if needed)

If either review reports FAIL:
1. Re-dispatch the implementer with the review feedback
2. Re-run the failing review
3. Max 3 iterations — if still failing after 3 rounds, escalate to user

### Step 6: Mark done and track size

- Close the ticket on GitHub: `gh issue close [number] --comment "Implemented in [branch]"`
- Report ticket completion:
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "build:ticket-completed" "{\"ticketNumber\":CURRENT_NUM,\"totalTickets\":TOTAL_NUM}"
  ```
- Track cumulative lines changed: `git diff --stat [base]..HEAD`
- If cumulative lines > ~400 and there are remaining tickets: suggest a PR split point to the user

### Between tickets

No gate — proceed to the next ticket automatically. Only pause if:
- An implementer is BLOCKED and you can't resolve it
- Cumulative lines suggest a PR split
- Something contradicts the build plan

---

## Phase 3: Create PR

**Goal:** Create a well-structured PR optimized for AI review.

### 1. Assess change size

Count total lines changed: `git diff --stat main..HEAD` (or the appropriate base branch).

- **≤ 400 lines** → single PR
- **> 400 lines** → split into stacked PRs at the boundaries the build-planner suggested (epic/feature boundaries)

### 2. Create the branch (if not already on one)

```bash
git checkout -b feat/[feature-name]
git push -u origin feat/[feature-name]
```

### 3. Create the PR

Use `gh pr create` with a HEREDOC body. Follow the template from `references/pr-template.md`.

### 4. Present summary

```
## Built: [Feature Name]

**PR:** [URL]
**Tickets closed:** #203, #204, #205
**Lines changed:** [N]

Suggest running review next — the full multi-agent PR review will catch anything the lightweight in-build reviews missed.
```

If stacked PRs were created, list all PR URLs with their ticket groupings.

---

## Key Principles

- **Sequential execution** — tickets build on each other. No parallel implementation.
- **Fresh context per implementer** — each subagent gets a clean start. No context pollution.
- **Lightweight review, not full review** — catch obvious issues between tickets. The full review happens against the PR.
- **Autonomous between tickets** — don't ask the user between every ticket. Only pause for blockers or PR splits.
- **Escalate, don't guess** — if an implementer is stuck, escalate rather than proceeding with uncertainty.
- **Size-aware PRs** — split at ~400 lines for reviewability.
- **Implementer prompt includes full ticket** — never make the subagent read from GitHub. Paste the content.

---

## Telemetry

After creating the PR and presenting the summary, report completion:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "build:pr-created" "{\"prNumber\":PR_NUMBER,\"linesChanged\":LINES_CHANGED}"
```

Replace `PR_NUMBER` with the PR number and `LINES_CHANGED` with total lines changed.
