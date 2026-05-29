# Module Flow — Diagnostic Reference

This file is used by `/guide` to infer where a participant is in the workshop based on project state signals. It maps the full fundamental track flow: modules, steps, artifacts, and common sticking points.

---

## Module 2a: PRD & Planning (milestone M1)

| Step | What happens | Command | Artifact produced | Done signal |
|------|-------------|---------|-------------------|-------------|
| 2a-1 | Install dev plugin | `/plugins` → development | Plugin active | `/prd` autocompletes |
| 2a-2 | Learn what a PRD is | Read module text | — | — (no artifact) |
| 2a-3 | Write PRD | `/prd` | `.prd/prd-v1.md` with `status: draft` | File exists, frontmatter has `status: draft` |
| 2a-4 | Learn EFT framework | Read module text | — | — (no artifact) |
| 2a-5 | Create tickets | `/tickets` | GitHub Issues with labels (P0/P1/P2, S/M/L, epic/feature/task) | `.prd/prd-v1.md` status flipped to `built`, `gh issue list` returns issues |
| 2a-6 | Explore GitHub | Open browser | — | — (teaching moment) |

**Common sticking points:**
- Participant unsure about project scope → `/prd` should adapt, but abandoned mid-conversation leaves an incomplete draft PRD
- GitHub authentication fails during `/tickets` → `gh auth status` reveals this
- No `.prd/` folder at all → participant hasn't run `/prd` yet

---

## Module 3a: Build & Review (milestone M2)

| Step | What happens | Command | Artifact produced | Done signal |
|------|-------------|---------|-------------------|-------------|
| 3a-1 | Understand build flow | Read module text | — | — |
| 3a-2 | Build tickets | `/build` | Code in feature branch, GitHub Issues closed, PR created | `git branch` shows feature branch, `gh pr list` shows open PR |
| 3a-3 | Understand PRs | Read module text + visit GitHub | — | — |
| 3a-4 | Review PR | `/pr-review` | Review comments posted on PR | `gh pr view --comments` shows review findings |
| 3a-5 | Fix review issues | Prompt Claude directly | Fixes committed to branch | Review findings addressed |
| 3a-6 | Merge PR | Prompt Claude or via GitHub | Code on `main`, PR closed | `gh pr list --state merged` shows merged PR |

**Common sticking points:**
- `/build` fails on a ticket → check `gh issue list --state open` for remaining tickets
- Build created a branch but no PR → interrupted between build and PR creation
- PR exists but no review comments → `/pr-review` hasn't been run yet
- Merge conflict → participant may have edited files manually during build
- Multiple open branches → parallel sessions or interrupted builds
- Detached HEAD → participant checked out a specific commit

---

## Module 4a: Test & Launch (milestone M3)

| Step | What happens | Command | Artifact produced | Done signal |
|------|-------------|---------|-------------------|-------------|
| 4a-1 | Launch locally | `/localhost` | Dev server running on port 3000 | `lsof -i :3000` shows process |
| 4a-2 | Test with checklist | Prompt Claude for test plan | Test plan (in conversation) | — |
| 4a-3 | Give feedback | Conversation with Claude | `.prd/prd-v2.md` with `status: draft` (if feedback given) | New PRD draft exists |
| 4a-4 | Close tickets | Prompt Claude or manually | All GitHub Issues closed | `gh issue list --state open` returns 0 |
| 4a-5 | Archive PRD | Prompt Claude or manually | `.prd/prd-v1.md` status → `archived` | Frontmatter shows `status: archived` |
| 4a-6 | Add rules to CLAUDE.md | Prompt Claude | `CLAUDE.md` updated with PRD lifecycle rules | File contains one-draft and no-edit-archived rules |
| 4a-7 | Deploy (optional) | `/launch` | Live Vercel URL, `.vercel/` folder | `vercel inspect` succeeds |

**Common sticking points:**
- Localhost fails → port conflict (`lsof -i :3000`), missing deps (`npm install`), build errors
- Vercel auth fails → `vercel whoami` errors, guide through `vercel login`
- Participant doesn't understand "note for next cycle, don't fix now" philosophy
- Old PRD still `built` instead of `archived` → lifecycle not followed
- GitHub Issues still open after merge → cleanup skipped

---

## Module 5a: Extra Time (no milestone — enrichment)

| Step | What happens | Command | Done signal |
|------|-------------|---------|-------------|
| 5a-* | Enrichment (a la carte) | `/buddy`, spinners, hooks, `/statusline`, `/powerup`, mini projects | No fixed done state |

No common sticking points — free exploration. If participant is here, ask what they want to do.

---

## Diagnostic Signal Tree

Check artifacts in this order to infer position:

```
1. Check for guided-build/ folder
   → Present: participant completed Module 1 warm-up
   → Absent: either skipped or hasn't started

2. Check .prd/ directory
   → Absent: pre-Module 2a (hasn't run /plan)
   → prd-v1.md status: draft, no GitHub remote
     → Mid-2a: between /prd and /tickets
   → prd-v1.md status: built, GitHub Issues exist (open)
     → End of 2a / start of 3a: ready for /build
   → prd-v1.md status: built, GitHub Issues exist (some closed)
     → Mid-3a: /build in progress

3. Check git branches and PRs
   → Feature branch exists, no PR
     → Mid-3a: /build done but PR not created
   → Open PR, no review comments
     → Mid-3a: between /build and /review
   → Open PR with review comments
     → Mid-3a: /pr-review done, fix or merge pending
   → Merged PR
     → End of 3a / start of 4a

4. Check PRD lifecycle state
   → prd-v1.md status: built, PR merged, Issues still open
     → Mid-4a: cleanup not done
   → prd-v1.md status: archived, Issues closed
     → 4a complete: ready for /launch or Module 5a
   → prd-v2.md exists with status: draft
     → 4a feedback cycle: next iteration ready

5. Check deployment
   → .vercel/ folder exists
     → /launch has been run (verify deployment succeeded)

6. Check for anomalies
   → Multiple draft PRDs → lifecycle violation
   → Detached HEAD → git state issue
   → Multiple feature branches → parallel sessions or interrupted builds
   → No git remote but code exists → /tickets skipped or failed
   → Merge conflicts → manual edits during automated build
```
