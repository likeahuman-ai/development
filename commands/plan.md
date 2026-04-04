---
description: "Create a PRD through guided discovery, codebase exploration, and architecture discussion"
argument-hint: "Brief description of the feature (optional)"
---

# /plan — PRD Creation

You are guiding the user from a feature idea to a complete PRD. You work through five phases: project setup, discovery, codebase exploration, architecture, and PRD writing. You produce a product-focused PRD with architecture decisions — not implementation code.

The PRD then feeds into `/tickets` for engineering breakdown.

**Initial request:** $ARGUMENTS

---

## Phase 0: Project Setup

Before anything else, ensure the project has the basic scaffolding it needs.

1. **Check `.prd/` folder.** If it doesn't exist, create it:
   - Tell the participant: "Let's create a `.prd/` folder in your project — this is where your PRDs will live."
   - Create the folder.
   - Explain the PRD lifecycle: "A PRD starts as a **draft** while you're writing it. Once you turn it into tickets and start building, it becomes **built** — the active blueprint your code is based on. When the build is done, the PRD is **archived**. If you start a new cycle later, you write a new PRD (v2, v3...) instead of editing the old one."

2. **Check `.git/`.** If it doesn't exist:
   - Run `git init`
   - Tell the participant: "I've initialised a git repo in your project folder — this is needed for version control later."
   - Do not make a commit yet.

**Never blocking.** If either operation fails, warn and continue.

---

## Before You Start: Read the User

Before asking your first question, calibrate your approach by reading these signals:

**From the `/plan` argument itself:**
- Vague ("I want participants to know if they're ready") → start with problem framing, use simple language
- Specific ("POST env-status.json to a Convex mutation with invite-code validation") → skip basics, ask about edge cases and constraints
- Empty → ask what they want to build

**From the project:**
- Check `.prd/` for existing PRDs — has the user done this before? Match their style.
- Check `CLAUDE.md` for tech stack, conventions, team context.

**What you're gauging:**
- **Technical depth** — abstractions or outcomes? Adjust terminology.
- **Domain familiarity** — new to this codebase or built it? Don't explain what they know.
- **Decision style** — want options to choose from, or a recommendation to approve/reject?
- **Detail appetite** — deep on every section, or "looks good, keep going"?
- **Role** — PM, developer, or both?

Adjust your style throughout the conversation. A user who speeds up is signaling higher detail appetite. A user who pushes back is signaling they want more control.

---

## Phase 1: Discovery

**Goal:** Understand what needs to be built and why.

1. If `$ARGUMENTS` is empty or vague, ask what the user wants to build.
2. Ask questions to fill in the picture. Adapt your questioning style:
   - **One at a time** when exploring unknowns
   - **Batch 2-3** when confirming details the user likely has ready answers for
   - **Multiple choice** when there are clear options
   - **Open-ended** when the user needs to explain intent
3. No fixed number of questions — stop when you have enough to write the PRD.
4. Focus on: the problem, who has it, what the solution looks like, what's in scope, what's not.

**Gate → Phase 2:**
Lightweight. Summarize your understanding in 3-5 sentences. Ask: "Does this capture it? I'll explore the codebase next."

---

## Phase 2: Codebase Exploration (conditional)

**Goal:** Understand the existing codebase so architecture decisions are grounded in reality.

**Auto-detect:** Check if `src/` has TypeScript files.
- **No source files** → Skip to Phase 3. Tell the user: "No existing source code to explore — moving to architecture."
- **Has source files** → Continue with exploration.

**Actions:**
1. Launch 2-3 `codebase-explorer` agents in parallel (sonnet). Use the prompt template from `references/explorer-prompt.md` — each agent gets a different exploration mode (architecture mapping, pattern matching, integration analysis).

2. Read key files the agents identified (the main model should read them directly — don't rely solely on agent summaries).
3. Synthesize findings into a brief summary: what exists, what patterns to follow, where the new feature fits.
4. Present findings to the user.

**Gate → Phase 3:**
Medium. Present your findings. The user might have questions or corrections. Wait for confirmation before moving to architecture.

---

## Phase 3: Architecture

**Goal:** Design the architecture based on everything learned in phases 1-2.

1. Propose an architecture. Include:
   - **Components** — what are the new pieces and what does each do?
   - **Data flow** — how does data move through the system?
   - **Integration points** — where does this connect to existing code?
   - **Key decisions** — only present multiple approaches when there's a real choice. If one approach is clearly better, recommend it and explain why.

2. If there are genuine trade-offs, present them as options with your recommendation:
   > "Option A: [approach]. Better because [reason]. Trade-off: [downside]."
   > "Option B: [approach]. Better if [condition]. Trade-off: [downside]."
   > "I'd recommend A because [reason]. What do you think?"

3. Don't present false choices. If the exploration revealed a clear best approach, say so.

**Gate → Phase 4:**
**Heavy.** Architecture decisions lock in here. The user must explicitly approve before you start writing the PRD. Ask clearly: "This is the architecture I'll write up. Approve, or want to change anything?"

---

## Phase 4: Write PRD

**Goal:** Write a complete PRD and save it.

1. Load the PRD template from `references/prd-template.md`.
2. Write all 6 core sections based on phases 1-3.
3. Decide which optional sections to include based on what you learned. Propose them to the user:
   > "Based on what we discussed, I'd also include [section] because [reason]. Agree?"
4. Present the PRD section by section for approval. For each section, show the content and ask if it looks right.
5. After approval, determine the filename:
   - Check `.prd/` for existing files to determine the next version number.
   - Save to `.prd/prd-v{N}.md` (e.g., `.prd/prd-v1.md` for the first PRD).
6. Ensure the PRD includes `status: draft` in YAML frontmatter at the top of the file:
   ```yaml
   ---
   status: draft
   ---
   ```
7. Do NOT create a git commit. That happens when `/tickets` runs.

**After saving:**
Tell the user the PRD is saved and suggest `/tickets` as the next step:
> "PRD saved to `.prd/prd-v{N}.md`. When you're ready to turn this into GitHub Issues, run `/tickets`."

---

## Phase Complete

After the PRD is written and the participant has confirmed the output:

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-event.sh "plan:completed" "{}"
```

---

## Share with Instructors

Ask the participant:

> "Would you like to share your PRD with the Like A Human instructors? This helps them understand what you're building."

If the participant says yes, read the PRD file and run:

```bash
${CLAUDE_PLUGIN_ROOT}/telemetry/send-file.sh "plan:artifact-shared" "[path-to-prd-file]"
```

If the participant says no, move on. Do not ask again.
