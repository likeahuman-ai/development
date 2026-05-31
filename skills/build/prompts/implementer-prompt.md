# Implementer Prompt Template

Use this template when `/build` dispatches an implementer subagent for a ticket.

## Prompt

> ## Implement: [TICKET TITLE]
>
> ### Ticket
> [Paste full ticket body — objective, context, requirements, acceptance criteria, constraints, dependencies]
>
> ### Context
> This is ticket [N] of [TOTAL] in the build sequence. Previous tickets already completed: [list titles]. The codebase reflects all prior work.
>
> ### The ticket is the spec
> Implement the ticket exactly as written — it is the approved plan. Do not re-design, re-scope, or re-confirm it. Start immediately. Stop only if faithful execution is *impossible*: a file, symbol, or dependency the ticket references does not exist, or two requirements directly contradict — then report NEEDS_CONTEXT with the specific blocker. A question whose answer is "yes, as the ticket says" is noise; don't ask it.
>
> ### Coding Standards
>
> {{coding_standards}}
>
> If coding standards are provided above, follow them. They reflect the participant's own conventions. If the slot is empty, follow existing codebase patterns only.
>
> ### Design Guide
>
> {{design_guide}}
>
> If a design guide is provided above, this ticket touches the UI — follow it so the result doesn't look like default AI output. If the slot is empty, this is a backend ticket; ignore this section.
>
> ### Your Job
> 1. **Implement** the ticket spec exactly. Follow existing codebase patterns and any coding standards above.
> 2. **Write tests** if the ticket includes test-related acceptance criteria.
> 3. **Verify** — run any verification commands from the acceptance criteria (`pnpm test`, `pnpm typecheck`, etc.).
> 4. **Commit** — granular commits per logical unit. Good commit messages.
>    - If a commit fails (pre-commit hook, lint, formatting), fix the issue and retry ONCE. If the second commit also fails, report BLOCKED with the exact error. Do not retry further.
> 5. **Self-review** — before reporting, review your own work:
>    - Did you implement everything in Requirements?
>    - Did you meet all Acceptance Criteria?
>    - Did you respect all Constraints?
>    - Did you overbuild anything not requested?
> 6. **Report** your status:
>    - **DONE** — all requirements met, tests pass, self-review clean
>    - **DONE_WITH_CONCERNS** — implemented but [specific concerns]
>    - **NEEDS_CONTEXT** — need clarification on [specific question]
>    - **BLOCKED** — cannot proceed because [specific blocker]

## Model Selection

- **S** (small) → sonnet
- **M** (medium) → sonnet
- **L** (large) → inherit (Opus)

## Handling Results

- **DONE** → proceed to spec review
- **DONE_WITH_CONCERNS** → assess concerns, then proceed to spec review
- **NEEDS_CONTEXT** → provide context, re-dispatch same model
- **BLOCKED** → provide more context, escalate model, break ticket down, or escalate to user
