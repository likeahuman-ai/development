---
description: "Review a PR with specialist agents and confidence scoring — surfaces only high-confidence findings"
argument-hint: "PR number or URL (optional — auto-detects current branch PR)"
---

# /review — PR Review

Follow the communication tone in `${CLAUDE_PLUGIN_ROOT}/references/tone.md`.

You are reviewing a PR with specialist agents and confidence-based scoring. You combine deep specialist analysis with aggressive noise filtering — only findings above confidence threshold reach the user (65% user-facing, 80% internal).

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
- **Files with message handlers, event listeners, or callback chains** (addEventListener, .on(, .subscribe, multi-step state flows) — triggers flow-tracer
- **Files with visual or styling code** (CSS, Tailwind classes, font imports, colour declarations, JSX components with styling) — triggers design-reviewer

### 2. Detect platform and inject context

Identify the project platform (e.g., Next.js, VS Code extension, CLI tool) from package.json, file structure, and framework markers. If a known platform is detected, inject the appropriate context into the `{{platform_context}}` slot in the review dispatch prompt (`references/review-prompt.md`).

### 3. Build the specialist roster

Always include:
- `code-quality-reviewer` (sonnet)
- `code-simplifier` (inherit) — runs after others

Conditionally include based on file classification above:
- `silent-failure-hunter` (sonnet)
- `type-design-reviewer` (inherit)
- `test-coverage-reviewer` (sonnet)
- `comment-analyzer` (sonnet)
- `history-reviewer` (sonnet)
- `flow-tracer` (sonnet) — when files contain message handlers, event listeners, callback chains, or multi-step state flows
- `design-reviewer` (sonnet) — when files contain visual or styling code. Use the dispatch prompt from `references/design-review-prompt.md`. Include the PRD's Visual Direction section if available.

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

Before applying the threshold, classify each finding:
- **User-facing** — visible UI bugs, broken buttons, data loss, broken user flows, visual regressions
- **Internal** — code quality, type safety, style, performance, error handling patterns

### 3. Filter (two-tier threshold)

Apply a two-tier threshold:
- **User-facing findings:** Drop below **65**. These are real bugs participants will see.
- **Internal findings:** Drop below **80**. This is the noise filter.

This recovers real user-facing bugs that scored 55-79 while keeping internal noise filtered.

### 4. Categorize survivors

- **Critical** (90-100) — must fix before merge
- **Important** (65-89 user-facing, 80-89 internal) — should fix
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
Confidence threshold: 65/100 user-facing, 80/100 internal
```

If no findings survived:

```markdown
### Code Review

No issues found. Reviewed for: [list what was checked based on agents that ran].

Confidence threshold: 65/100 user-facing, 80/100 internal
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

## Phase 6: Fix Cycle

**Goal:** Send the participant to GitHub to read the findings, then offer to fix them.

This phase only runs if findings survived scoring. If no findings, skip to Phase Complete.

### 1. Send them to GitHub

> "I've posted the findings to your pull request — go have a look at the comments: [PR URL]."

Wait for them to come back. Don't rush this — reading review comments on GitHub is a teaching moment. The participant learns what a code review looks like.

### 2. Offer to fix

> "Want me to fix these?"

### 3. If yes — fix directly

The main model works through the fixes. No subagents, no special scaffolding — just Claude fixing what the review found.

For each finding:
1. Read the finding description and the relevant code
2. Apply the fix
3. Briefly note what was changed: "Fixed [description] in [file]"

After all fixes are applied, commit the changes:
```bash
git add -A && git commit -m "fix: address review findings"
git push
```

### 4. If no — move on

Respect the answer. The participant may want to fix things themselves or may be happy with the code as-is.

---

## Phase Complete

After findings are posted to the PR (and optionally fixed):

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "review:completed" "{\"findingsCount\":FINDINGS_COUNT,\"criticalCount\":CRITICAL_COUNT}"
```

If fixes were applied:

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "review:fixes-applied" "{}"
```

---

## Share with Instructors

Ask the participant:

> "Would you like to share your review findings summary with the Like A Human instructors? This helps them offer guidance on code quality."

If the participant says yes, construct a findings summary (count per severity, finding descriptions, no code snippets) and run:

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "review:artifact-shared" "FINDINGS_SUMMARY_JSON"
```

If the participant says no, move on. Do not ask again.

---

## Key Principles

- **Only real issues** — the two-tier threshold exists to prevent noise while catching user-facing bugs. Trust it.
- **Evidence required** — no finding without file:line and code snippet.
- **Changed code only** — never flag pre-existing issues.
- **No CI duplication** — don't flag what linters, typecheckers, or tests catch.
- **Cheap where possible** — Haiku for eligibility and scoring, sonnet/inherit for actual review.
- **Simplifier runs last** — it benefits from seeing other agents' findings to avoid overlap.
- **Full SHA in links** — abbreviated SHAs break GitHub links.
