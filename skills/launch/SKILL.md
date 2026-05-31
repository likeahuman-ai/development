---
name: launch
allowed-tools: Bash(vercel:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*)
description: >
  Deploy your project to Vercel — get a live URL anyone can visit.
  Use when participant wants to deploy, says 'deploy', 'make it live', 'ship it',
  'launch it', 'get a URL', or wants to share their project with others.
---

# /launch — Deploy to Vercel

Follow the communication tone in `${CLAUDE_PLUGIN_ROOT}/skills/launch/prompts/tone.md`.

You are deploying the participant's project to Vercel. You handle prerequisites (auth, git), run the deployment, and send the participant to explore the Vercel dashboard.

**Initial request:** $ARGUMENTS

---

## Phase 1: State Detection

**Goal:** Ensure everything is ready for deployment.

### 1. Check Vercel CLI

```bash
which vercel
```

If not installed:
- macOS: `brew install vercel-cli`
- Windows: `npm i -g vercel`

These match the workshop extension's install methods.

### 2. Check Vercel authentication

```bash
vercel whoami
```

If not authenticated:
- Guide through `vercel login` — this opens a browser for OAuth.
- Tell the participant: "Sign in with your GitHub account. If you don't have a Vercel account yet, you can create one using your GitHub account."
- Wait for the login to complete (the CLI confirms automatically).

### 3. Check git status

```bash
git status --porcelain
```

If there are uncommitted changes:
- Warn: "You have uncommitted changes. These won't be included in the deployment."
- Commit them:
  ```bash
  git add -A
  git commit -m "pre-deploy: commit all changes"
  ```

Push to remote:
```bash
git push
```

---

## Phase 2: Deploy

**Goal:** Deploy and capture the URL.

Run the deployment:

```bash
vercel --yes
```

The `--yes` flag is essential — it skips all interactive prompts (and avoids a known Windows bug where the CLI exits silently without prompting).

This creates a **preview deployment** (not production). Preview is the safe default for a workshop — it gives a live URL without touching production domains.

Capture the deployed URL from stdout.

---

## Phase 3: Verify

**Goal:** Confirm the deployment succeeded.

```bash
vercel inspect [deployment-url]
```

Check the status field:
- **READY** — deployment succeeded. Proceed.
- **ERROR** — deployment failed. Run `vercel logs [deployment-url]` and translate the error to plain language. Common issues:
  - **Case sensitivity:** macOS and Windows are case-insensitive, but Vercel runs Linux. Check for `Components/` vs `components/` mismatches.
  - **Build error:** Missing dependency, TypeScript error, or config issue. Read the logs and suggest a fix.
  - **If it fails twice:** tell the participant the code is on GitHub and deployment can happen later. Don't block the workshop.

Add `.vercel/` to `.gitignore` if not already present (Vercel creates this directory on first deploy).

---

## Phase 4: Celebrate and Explore

**Goal:** Celebrate the deployment, introduce the Vercel dashboard, and suggest what's next.

Tell the participant:
> "Your project is live at [URL]. Open it in your browser!"

Then:
> "Now open **vercel.com/dashboard** in your browser. Find your project — you can see build logs, deployment history, and settings. This is where you manage your deployments."

### What's Next

After the participant has seen their deployment:

> "You've finished the fundamental dev flow — plan, build, review, launch. A few options from here:"
> - "Want to keep building? Run `/plan` to start your next cycle — maybe tackle the feedback from testing, or add new features."
> - "Want to have some fun? Module 5a has extras — customise Claude Code, build a mini project, get a virtual buddy."
> - "Want a break? You've earned it."

This is editorial — just a message. Don't force a choice. The participant may also be guided by the online module or the instructor.

---

## Rules

- **`--yes` is essential** — never run `vercel` without it. Skips prompts and avoids the Windows bug.
- **Preview, not production** — `vercel --yes` creates a preview deployment by default. This is correct for the workshop.
- **GitHub SSO for auth** — always guide participants to sign in with their GitHub account.
- **Never run `vercel ls`, `vercel link`, or `vercel project inspect`** in unlinked directories — these have interactive side effects.
- **Don't block the workshop** — if deployment fails after two attempts, move on. The code is on GitHub.
- **Send them to the dashboard** — don't just give a URL. The Vercel dashboard is a teaching moment about deployment infrastructure.
