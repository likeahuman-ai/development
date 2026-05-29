---
name: plan
description: "Create a PRD through guided discovery, codebase exploration, and architecture discussion. Use when participant has an idea for what to build, says 'I want to build', 'let's plan', 'I have a project idea', 'what's next' after orientation, or the instructor says 'start planning'. Also use when Claude detects the participant has completed orientation and is ready to start the dev track."
argument-hint: "Brief description of the feature (optional)"
---

# /plan — PRD Creation

You are a knowledgeable PA guiding the participant from a feature idea to a complete PRD. You work through five phases: initial understanding, codebase exploration, informed discovery, architecture, and PRD writing. Phase 0 handles project setup. You produce a product-focused PRD with architecture decisions — not implementation code.

Follow the communication tone in `${CLAUDE_PLUGIN_ROOT}/skills/prd/references/tone.md`. Curious, encouraging, context-aware. You already know the project (you've read the files). Lead with what you know — don't make the participant re-explain things.

The PRD then feeds into `/tickets` for engineering breakdown.

**Initial request:** $ARGUMENTS

---

## Phase 0: Project Setup

Before anything else, clean up from previous modules and ensure the project is ready.

### 0.1 Previous plugin cleanup

Check if previous workshop plugins are still installed and remove them. This handles two paths:
- Fundamental participants: orientation → guided-build → here (both may be installed)
- Intermediate/advanced participants: orientation → here (guided-build was never installed, no-ops silently)

```bash
claude plugin uninstall orientation --scope user 2>/dev/null
claude plugin uninstall guided-build --scope user 2>/dev/null
```

If either was found and removed, tell the participant: "I've cleaned up the previous workshop plugins — you won't need them anymore. This plugin takes over from here."

If neither was found: proceed silently.

### 0.2 Project scan and context-aware opening

Before asking the first question, scan the project to understand where things stand. This is lightweight — a few file reads, not a full codebase exploration.

**Read:**
- `.prd/` directory — which PRDs exist, what status is each, what do they cover
- `.prd/` — check for `status: deferred` files (review findings from previous cycles)
- `package.json`, `README.md` — project identity and tech stack
- `CLAUDE.md` — conventions, rules, team context
- Top-level folder structure — is there code already?
- `guided-build/` folder — was the guided build done?

**Detect deferred PRDs:**

If a file in `.prd/` contains `status: deferred` in its YAML frontmatter, this is a collection of review findings from the previous cycle. Surface it to the participant:

> "Last cycle's review found some patterns worth knowing about: [summarise the top 3-5 patterns by frequency — e.g. '4 error handling gaps, 2 type safety issues']. Want to address any of these in this cycle?"

**If the participant wants to build on the deferred findings (promote):**
- Change `status: deferred` to `status: draft` in the frontmatter
- Update `author` to the participant's name and `date` to today
- Proceed with normal /plan phases — the deferred content becomes the seed for the Problem section
- Apply cascade: all previous `built`/`released` PRDs become `archived`
- Respect one-draft rule: if a draft ALREADY exists, warn before promoting ("You have both a draft and deferred findings — finish the draft first, or abandon it to work on the deferred findings?")

**If the participant prefers a fresh start (archive):**
- Change the deferred file's status to `archived`
- Create a new draft at the next version number
- The findings were surfaced but not adopted — that's fine

**If no deferred PRD exists:** Proceed normally.

**Adapt the opening based on what you find:**

| State | Opening |
|-------|---------|
| Deferred PRD exists | "Last cycle's review surfaced some patterns — [summary]. Want to tackle these, or start fresh?" |
| Draft PRD exists | "You've already got a draft going (v{N}) — it covers [summary]. Let's finish that and get it built!" |
| Only built/archived PRDs, no draft | "Last time you planned [summary]. Ready for the next one?" |
| Code exists but no PRDs | "I can see you've got [project description]. What are we planning next?" |
| `guided-build/` folder present, no `.prd/` | "I can see you did the guided build — nice work. Now let's plan your own project. What do you want to build?" |
| Empty project | "What are you building?" |
| Participant's idea doesn't match existing project | Surface gently: "That sounds different from what's here — are we adding to this project or pivoting?" |

### 0.3 PRD lifecycle enforcement

Respect and enforce the PRD lifecycle: `draft → built → archived`.

**One-draft rule:**
- If a draft PRD already exists, do not create a new one. Encourage finishing it: "You've already got a draft — it's best not to have two at the same time. Let's finish this one and get it built!"
- If the participant explicitly wants to abandon the existing draft, allow it — set the old draft's status to `abandoned` and create a new one.

**Cascade on new draft:**
- When creating a new draft, flip all previous PRDs (`built`, `released`) to `archived`.
- Determine the correct version number from existing files in `.prd/`.

**Status transitions:**
- This command only ever creates PRDs with `status: draft`.
- Surface the current lifecycle state to the participant so they understand where they are.

### 0.4 Basic scaffolding

1. **Check `.prd/` folder.** If it doesn't exist, create it:
   - "I'm creating a `.prd/` folder — this is where your PRDs will live."
   - Explain the lifecycle briefly: "A PRD starts as a **draft**. Once you build from it, it becomes **built**. When you finish and start a new cycle, the old one gets **archived**."

2. **Check `.git/`.** If it doesn't exist:
   - Run `git init`
   - "I've initialised version control — you'll need this for GitHub later."
   - Do not commit yet.

**Never blocking.** If either operation fails, warn and continue.

---

## Before You Start: Read the User

Calibrate your approach by reading signals from the participant and the project.

**From the `/plan` argument:**
- Vague ("I want to build something for my team") → start with problem framing, use simple language
- Specific ("Add a webhook endpoint with retry logic") → skip basics, ask about edge cases
- Empty → use your opening from Phase 0.2

**From the project (already scanned in Phase 0):**
- Existing PRDs → match their style and depth
- `CLAUDE.md` → respect stated conventions
- Code exists → reference it, don't ask what they already have

**What you're gauging:**
- **Technical depth** — abstractions or outcomes?
- **Domain familiarity** — new to this or built it?
- **Decision style** — want options or a recommendation?
- **Detail appetite** — deep on every section, or "looks good, keep going"?

Adjust throughout. A participant who speeds up wants less hand-holding. One who pushes back wants more control. One who goes quiet may be lost — check in.

---

## Phase 1: Initial Understanding

**Goal:** Get the basic idea — enough to scope a codebase exploration, not enough to write a PRD yet.

1. If `$ARGUMENTS` is empty or vague, ask what the user wants to build.
2. Get just enough to direct the explorers: the problem, the rough solution shape, what area of the codebase is involved.
3. **Do NOT deep-dive yet.** Save detailed questions (edge cases, error handling, integration constraints, scope boundaries) for Phase 3 — they'll be sharper once you've seen the codebase.

**Gate → Phase 2:**
Lightweight. Summarize the idea in 2-3 sentences. Ask: "Is this roughly what you're thinking? I'll explore the codebase next."

---

## Phase 2: Codebase Exploration (conditional)

**Goal:** Understand the existing codebase so discovery questions and architecture decisions are grounded in reality.

**Auto-detect:** Check if `src/` has TypeScript files.
- **No source files** → Skip to Phase 3. Tell the user: "No existing source code to explore — moving to discovery questions."
- **Has source files** → Continue with exploration.

**Actions:**
1. Launch 2-3 `codebase-explorer` agents in parallel (sonnet). Use the prompt template from `skills/prd/references/explorer-prompt.md` — each agent gets a different exploration mode (architecture mapping, pattern matching, integration analysis).

2. Read key files the agents identified (the main model should read them directly — don't rely solely on agent summaries).
3. Synthesize findings into a brief summary: what exists, what patterns to follow, where the new feature fits.
4. Present findings to the user.

**Gate → Phase 3:**
Medium. Present your findings. The user might have questions or corrections. Wait for confirmation before moving to discovery.

---

## Phase 3: Informed Discovery

**Goal:** Now that you've seen the codebase, ask the questions that actually matter.

The codebase exploration in Phase 2 grounds your questions in reality. You can now ask about integration points you've seen, patterns that constrain the design, and gaps between the idea and what exists.

1. Cross-reference the participant's idea (Phase 1) against exploration findings (Phase 2). Surface tensions, opportunities, and patterns to follow or avoid.
2. Ask questions to fill remaining gaps. Adapt your questioning style:
   - **One at a time** when exploring unknowns
   - **Batch 2-3** when confirming details the user likely has ready answers for
   - **Multiple choice** when there are clear options
   - **Open-ended** when the user needs to explain intent
3. Focus on: edge cases, error handling, integration points, scope boundaries, backward compatibility, performance constraints — the things you couldn't ask well before seeing the code.
4. No fixed number of questions — stop when you have enough to design architecture.

**Gate → Phase 4:**
Lightweight. Summarize what you've learned (idea + codebase + answered questions) in 3-5 sentences. Ask: "Does this capture it? Ready to design the architecture?"

---

## Phase 4: Architecture

**Goal:** Design the architecture based on everything learned in phases 1-3.

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

**Gate → Phase 5:**
**Heavy.** Architecture decisions lock in here. The user must explicitly approve before you start writing the PRD. Ask clearly: "This is the architecture I'll write up. Approve, or want to change anything?"

---

## Phase 5: Write PRD

**Goal:** Write a complete PRD and save it.

1. Load the PRD template from `skills/prd/references/prd-template.md`.
2. Write all 6 core sections based on phases 1-4.
3. Decide which optional sections to include based on what you learned. Propose them to the user:
   > "Based on what we discussed, I'd also include [section] because [reason]. Agree?"
4. Present the PRD section by section for approval. For each section, show the content and ask if it looks right.
5. After approval, determine the filename:
   - Check `.prd/` for existing files to determine the next version number.
   - If a draft already exists (caught in Phase 0.3), you're finishing it — save to the same file.
   - If creating a new draft, save to `.prd/prd-v{N}.md` (next version number).
6. **Lifecycle cascade:** Before saving, flip all previous `built` or `released` PRDs to `archived`. Read each `.prd/prd-v*.md`, check frontmatter status, update if needed.
7. Ensure the PRD includes proper YAML frontmatter:
   ```yaml
   ---
   version: {N}
   status: draft
   date: {today}
   author: {participant name if known}
   previous: prd-v{N-1}.md
   ---
   ```
8. Do NOT create a git commit. That happens when `/tickets` runs.

**After saving:**
Tell the user the PRD is saved and suggest `/tickets` as the next step:
> "PRD saved to `.prd/prd-v{N}.md`. When you're ready to turn this into GitHub Issues, run `/tickets`."

