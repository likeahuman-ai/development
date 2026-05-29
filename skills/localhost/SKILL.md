---
name: localhost
description: >
  Run your project locally — start the dev server and get a test plan.
  Use when participant wants to test locally, says 'run it', 'test it locally', 'does it work',
  'check localhost', 'start the dev server', or the instructor says 'test your project'.
---

# /localhost — Local Testing

Follow the communication tone in `${CLAUDE_PLUGIN_ROOT}/skills/localhost/references/tone.md`.

You are helping the participant run their project locally and giving them a test plan. This is a lightweight command — start the server, hand them a checklist, let them test independently. The scaffolding is intentionally loosened at this stage.

**Initial request:** $ARGUMENTS

---

## Phase 1: Start the Dev Server

**Goal:** Get the project running on localhost.

1. Check if a dev server is already running on port 3000.
   - If port is in use: ask if they want to use it or kill the existing process (`npx kill-port 3000` works cross-platform).

2. Detect Docker container:
   <!-- Docker detection — keep in sync with guided-build/1-build/skills/guided-build/SKILL.md Phase 4.1 -->
   ```bash
   [ -f /.dockerenv ] && echo "CONTAINER=true" || echo "CONTAINER=false"
   ```
   If `CONTAINER=true`, the dev server must bind to `0.0.0.0` so the host browser can reach it through Docker port forwarding.

3. Start the dev server:

   **If container:**
   ```bash
   npx next dev -H 0.0.0.0
   ```
   If `pnpm` is used: `pnpm next dev -H 0.0.0.0`

   **If not container:**
   ```bash
   npm run dev
   ```
   If `pnpm` is used: `pnpm dev`

4. Tell the participant:
   > "Your project is running. Open `http://localhost:3000` in your browser."
   >
   > "If you see a system popup about network access, click Allow. If you already clicked Deny, don't worry — localhost still works in your browser."

4. Wait for confirmation that the participant can see the app in their browser.

If the dev server fails to start, help debug:
- Port conflict → offer to use a different port or kill the blocking process
- Missing dependencies → run `npm install` or `pnpm install`
- Build errors → read the error output and suggest fixes
- Can't reach the page from browser (container) → check binding is `0.0.0.0`, not `127.0.0.1`. Restart with `-H 0.0.0.0`
- Hot-reload not working (container) → set `export WATCHPACK_POLLING=true` and restart the server

---

## Phase 2: Test Plan

**Goal:** Give the participant a checklist to test independently.

1. Read the PRD (check `.prd/` for the most recent file).
2. Generate a test plan checklist from the PRD's features and success metrics. For each feature:
   - What to do (the action)
   - What "working" looks like (the expected result)

Present the checklist:

```
## Test Plan

Based on your PRD, here's what to check:

- [ ] **[Feature 1 name]** — [action to take]. You should see: [expected result].
- [ ] **[Feature 2 name]** — [action to take]. You should see: [expected result].
- [ ] **[Feature 3 name]** — [action to take]. You should see: [expected result].

Go through each item in your browser. When you're done, tell me which ones passed and which didn't.
```

Let the participant test independently. Do not walk them through each feature.

---

## Phase 3: Results

**Goal:** Collect test results.

When the participant reports back:

1. Summarise: "X passed, Y failed."

---

## Phase 4: Feedback Loop

**Goal:** If there are issues, capture the feedback and defer the next planning cycle to `/prd`.

If the participant reported failures or has feedback:

1. **Lifecycle cascade first.** Before creating a new draft, flip all `built` PRDs in `.prd/` to `archived`. Read each `prd-v*.md`, check frontmatter status, update if needed. This is a fallback — participants are taught to do this themselves in the module, but the plugin catches it if they don't.

2. **Scaffold a new PRD draft** at `.prd/prd-v{N}.md` (next version number) with the feedback as starting content:
   ```yaml
   ---
   version: {N}
   status: draft
   date: {today}
   previous: prd-v{N-1}.md
   ---
   ```
   Include the issues found and any improvement ideas the participant mentioned. Keep it brief — this is a seed for `/prd`, not a complete PRD.

3. **Defer to `/prd` for the full writing.** Tell the participant:
   > "I've saved your feedback into a new PRD draft at `.prd/prd-v{N}.md`. Start a new session and run `/prd` to continue writing it — or if you're happy with what you've got, would you like to launch?"

   `/prd` owns the full PRD writing flow. It will find this draft in Phase 0.2 and pick up where `/localhost` left off.

If everything passed and the participant has no feedback, this phase is complete. The module will guide them to the next step.

---

## Rules

- **Lightweight.** Start the server, give them a checklist, let them go.
- **Do NOT direct the participant to `/launch`** — the module handles that transition.
- **Read the PRD for features** — don't ask the participant to list them.
- **Independent testing** — the participant works through the checklist on their own. Only help if they ask.
