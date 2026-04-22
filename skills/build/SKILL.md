---
name: build
description: "Implement GitHub Issue tickets sequentially with subagent execution, lightweight review, and PR creation. Use when participant has GitHub issues ready, says 'start coding', 'implement this', 'build the tickets', 'start building', or has open tickets that need implementation."
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

**HARD RULE — You are the orchestrator, NOT the implementer.**

You MUST NOT write implementation code, edit source files, or run project commands (`pnpm test`, `pnpm build`, `pnpm typecheck`, etc.) yourself. All implementation work happens inside subagents. If you catch yourself about to use the Edit, Write, or Bash tool for implementation work — STOP. That work belongs to a subagent.

**Allowed tools during Phase 2:**

| Tool | Allowed | Purpose |
|------|---------|---------|
| Agent | YES | Dispatch implementer, spec reviewer, quality reviewer |
| Bash (`git`, `gh`) | YES | Git operations, GitHub CLI, tracking line counts |
| Bash (project commands) | NO | `pnpm test`, `pnpm build`, etc. belong to the subagent |
| Read | YES | Reading subagent results, codebase files for prompt enrichment |
| Grep / Glob | YES | Codebase queries to inform dispatch prompts |
| Edit / Write | NO | All file modifications happen inside subagents |

For each ticket in the approved build order, execute this loop:

### Step 1: Prepare the dispatch prompt

Before dispatching, enrich the implementer prompt with codebase context:
1. Read the full ticket content from GitHub
2. Read relevant codebase files the implementer will need (patterns, types, adjacent code)
3. Load the prompt template from `skills/build/references/implementer-prompt.md`
4. Fill in: ticket content, sequence position, prior ticket titles, and relevant file contents

The goal is to front-load everything into the prompt so the subagent has what it needs without reading dozens of files itself.

### Step 2: Dispatch implementer

You MUST call the Agent tool to dispatch the implementer. Use `isolation: "worktree"` for a clean repo copy. Select model based on ticket complexity:
- **S** (small) → `model: "sonnet"`
- **M** (medium) → `model: "sonnet"`
- **L** (large) → `model: "opus"` or omit (inherits Opus)

```
Agent tool call:
  description: "Implement #[number] [short title]"
  model: "sonnet" (or "opus" for L)
  isolation: "worktree"
  prompt: [enriched implementer prompt]
```

Do NOT implement the ticket yourself. Do NOT "quickly do it" because it seems small. Every ticket gets a subagent.

### Step 3: Handle implementer result

- **DONE** → proceed to review
- **DONE_WITH_CONCERNS** → read the concerns, assess whether they matter, then proceed to review
- **NEEDS_CONTEXT** → provide the missing context from your knowledge of the PRD/codebase, re-dispatch the implementer via the Agent tool with the same model
- **BLOCKED** → assess the blocker:
  1. Can you provide more context? → re-dispatch via Agent tool with context
  2. Would a more capable model help? → re-dispatch via Agent tool with `model: "opus"`
  3. Should the ticket be broken down? → tell the user
  4. Is it a real blocker? → escalate to the user

### Step 4: Lightweight spec review

You MUST call the Agent tool to dispatch a spec reviewer (sonnet). Use the prompt template from `skills/build/references/spec-reviewer-prompt.md`. Paste the ticket spec and implementer report into the Agent prompt.

### Step 5: Lightweight quality review

Only if spec review passed. You MUST call the Agent tool to dispatch a quality reviewer (sonnet). Use the prompt template from `skills/build/references/quality-reviewer-prompt.md`. Paste the ticket description and changed files into the Agent prompt.

### Step 6: Fix loop (if needed)

If either review reports FAIL:
1. Re-dispatch the implementer via the Agent tool with the review feedback
2. Re-run the failing review via the Agent tool
3. Max 3 iterations — if still failing after 3 rounds, escalate to user

### Step 7: Mark done and track size

- Close the ticket on GitHub: `gh issue close [number] --comment "Implemented in [branch]"`
- Track cumulative lines changed: `git diff --stat [base]..HEAD`
- If cumulative lines > ~400 and there are remaining tickets: suggest a PR split point to the user

### Step 8: Ticket telemetry

After each ticket is implemented and its GitHub Issue is closed:

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "build:ticket-completed" "{\"ticketNumber\":TICKET_NUM,\"totalTickets\":TOTAL}"
```

Replace `TICKET_NUM` and `TOTAL` with the current ticket number and total ticket count.

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

Use `gh pr create` with a HEREDOC body. Follow the template from `skills/build/references/pr-template.md`.

### 4. PR telemetry

After the PR is created:

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "build:pr-created" "{\"prNumber\":PR_NUM,\"linesChanged\":LINES}"
```

Replace `PR_NUM` and `LINES` with the PR number and total lines changed.

### 5. Present summary

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

- **You are the orchestrator** — you coordinate, you do not implement. Every ticket and every review gets a subagent via the Agent tool. No exceptions, no "just this small one."
- **Sequential execution** — tickets build on each other. No parallel implementation.
- **Fresh context per implementer** — each subagent gets `isolation: "worktree"` for a clean repo copy and clean context window.
- **Prompt enrichment over file reading** — front-load codebase context into the Agent prompt. The subagent should rarely need to explore the codebase itself.
- **Lightweight review, not full review** — catch obvious issues between tickets. The full review happens against the PR.
- **Autonomous between tickets** — don't ask the user between every ticket. Only pause for blockers or PR splits.
- **Escalate, don't guess** — if an implementer is stuck, escalate rather than proceeding with uncertainty.
- **Size-aware PRs** — split at ~400 lines for reviewability.
