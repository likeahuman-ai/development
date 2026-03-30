---
description: "Review a PR with specialist agents and confidence scoring — surfaces only high-confidence findings"
argument-hint: "PR number or URL (optional — auto-detects current branch PR)"
---

# /review — PR Review

You are reviewing a PR with specialist agents and confidence-based scoring. You combine deep specialist analysis with aggressive noise filtering — only findings above 80% confidence reach the user.

You are mostly autonomous. No gates — run the full pipeline and present results.

**Initial request:** $ARGUMENTS

---

## Phase 1: Eligibility

**Goal:** Find the PR and check if it's worth reviewing. Use Haiku-level reasoning — this is a yes/no decision.

### 1. Find the PR

- If `$ARGUMENTS` contains a PR number or URL, use that.
- Otherwise, detect the current branch's PR: `gh pr view --json number,title,state,isDraft,additions,deletions,files`
- If no PR found, tell the user: "No PR found for the current branch. Specify a PR number or URL."

### 2. Check eligibility

Skip the review (tell the user why) if:
- PR is closed or merged
- PR is a draft (suggest: "This PR is still a draft. Run `/review` again when it's ready.")
- PR has 0 changed files
- PR changes only lock files, generated files, or non-code assets

Otherwise, proceed.

### 3. Gather PR context

```bash
gh pr view [number] --json number,title,body,headRefName,baseRefName,additions,deletions
gh pr diff [number]
```

Get the full SHA for code links: `git rev-parse HEAD`

---

## Phase 2: Summarize

**Goal:** Understand what changed and determine which specialists to run. Haiku-level reasoning.

### 1. Categorize changed files

Read the diff and classify each file:
- **TypeScript source** — triggers code-quality-reviewer
- **Error handling code** (try/catch, .catch, error callbacks) — triggers silent-failure-hunter
- **Type definitions** (.types.ts, interfaces, type aliases) — triggers type-design-reviewer
- **Test files** (.test.ts, .spec.ts) — triggers test-coverage-reviewer
- **Files with code comments** (JSDoc, inline comments) — triggers comment-analyzer
- **Files with high git churn** (check `git log --oneline -10 -- [file]`) — triggers history-reviewer
- **Message handlers, event listeners, callback chains** — triggers flow-tracer

### 2. Build the specialist roster

Always include:
- `code-quality-reviewer` (sonnet)
- `code-simplifier` (inherit) — runs after others

Conditionally include based on file classification above:
- `silent-failure-hunter` (sonnet)
- `type-design-reviewer` (inherit)
- `test-coverage-reviewer` (sonnet)
- `comment-analyzer` (sonnet)
- `history-reviewer` (sonnet)
- `flow-tracer` (sonnet) — traces state/message flows across handler boundaries

---

## Phase 3: Specialist Review

**Goal:** Run specialist agents in parallel and collect findings.

### 1. Dispatch agents

Load `references/review-prompt.md` for the dispatch template. Launch all selected agents in parallel (except code-simplifier).

For each agent, provide:
- PR context (number, title, description)
- The relevant portion of the diff (scoped to the agent's focus area)
- Changed file list
- Clear instruction to review only changed code

**Example dispatch for code-quality-reviewer:**
> Review PR #[number] "[title]" for bugs, logic errors, and missing error handling. Here is the diff: [diff]. Review only changed lines. For each finding include file:line, evidence, impact, and suggestion.

**Example dispatch for silent-failure-hunter:**
> Review PR #[number] "[title]" for silent failures. Here are the files with error handling code: [relevant diff sections]. Find swallowed errors, empty catches, and fire-and-forget operations.

### 2. Dispatch code-simplifier last

After all other agents return, dispatch `code-simplifier` with:
- The full diff
- Findings from other agents (so it doesn't duplicate their work)

### 3. Collect all findings

Gather findings from all agents. Each finding should have:
- Description
- File path and line number
- Evidence (code snippet)
- Which agent found it
- Suggested fix

---

## Phase 4: Confidence Scoring

**Goal:** Score each finding and filter out noise. Haiku-level reasoning per finding.

### 1. Score each finding

For each finding, evaluate (dispatch as parallel Haiku agents for speed):

**Scoring rubric (0-100):**
- Is the evidence specific — file, line, code snippet? (+20)
- Is the issue in code the PR actually changed? (+20)
- Would a senior engineer flag this? (+20)
- Is this a real bug or a preference? (+20 for real bug)
- Could CI catch this instead? (-20 if yes)

Scores:
- **0** — false positive, doesn't hold up
- **25** — might be real, might be false positive
- **50** — real but minor, nitpick territory
- **75** — verified real, will impact functionality
- **100** — certain, confirmed with evidence

### 2. Classify each finding

Before filtering, classify each finding as either:
- **User-facing** — visible UI bugs, broken interactions, data loss, accessibility failures
- **Internal** — code quality, type safety, style, performance, maintainability

### 3. Filter (two-tier threshold)

Apply different thresholds based on classification:
- **Internal findings:** drop below **80** (unchanged from v1)
- **User-facing findings:** drop below **65** (lower bar — false negatives here are expensive)

This recovers real user-visible bugs that the flat 80 threshold was dropping.

### 4. Categorize survivors

- **Critical** (90-100) — must fix before merge
- **Important** (80-89 internal, 65-89 user-facing) — should fix
- **Suggestions** — improvement opportunities above threshold

---

## Phase 5: Report

**Goal:** Comment on the PR and present findings to the user.

### 1. Format the PR comment

If findings survived scoring:

```markdown
### Code Review

Found [N] issues:

1. **[Critical/Important]** [brief description] — found by [agent name]

   https://github.com/[owner]/[repo]/blob/[FULL-SHA]/[path]#L[start]-L[end]

2. **[Critical/Important]** [brief description] — found by [agent name]

   https://github.com/[owner]/[repo]/blob/[FULL-SHA]/[path]#L[start]-L[end]

---

Reviewed by: [list of agents that ran]
Confidence threshold: 80 (internal) / 65 (user-facing)
```

If no findings survived:

```markdown
### Code Review

No issues found. Reviewed for: [list what was checked based on agents that ran].

Confidence threshold: 80 (internal) / 65 (user-facing)
```

### 2. Post the comment

```bash
gh pr comment [number] --body "[comment]"
```

### 3. Present to user

Show the user:
- How many findings each agent produced vs how many survived scoring
- The surviving findings grouped by severity
- Which agents ran and what they checked

```
## Review: PR #[number] — [title]

**Agents:** [list] | **Findings:** [N raw] → [M after scoring]

### Critical
- [finding with file:line]

### Important
- [finding with file:line]

### Clean Areas
- [what was checked and found clean]
```

---

## Key Principles

- **Only real issues** — the threshold exists to prevent noise. Trust it.
- **Evidence required** — no finding without file:line and code snippet.
- **Changed code only** — never flag pre-existing issues.
- **No CI duplication** — don't flag what linters, typecheckers, or tests catch.
- **Cheap where possible** — Haiku for eligibility and scoring, sonnet/inherit for actual review.
- **Simplifier runs last** — it benefits from seeing other agents' findings to avoid overlap.
- **Full SHA in links** — abbreviated SHAs break GitHub links.

---

## Telemetry

After presenting results to the user, report completion:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "review:completed" "{\"findingsCount\":FINDINGS_COUNT,\"criticalCount\":CRITICAL_COUNT}"
```

Replace `FINDINGS_COUNT` with the number of findings that survived scoring, and `CRITICAL_COUNT` with the number scored 90+.
