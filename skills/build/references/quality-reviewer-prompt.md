# Code Quality Review Prompt Template

Use this template when `/build` dispatches a quality reviewer after spec compliance passes.

## Prompt

> ## Code Quality Review
>
> ### What Was Built
> [Brief description of ticket]
>
> ### Changed Files
> [List files from implementer report]
>
> Review for obvious issues ONLY — this is not a full review. Check:
> 1. **Bugs** — logic errors, missing error handling, race conditions
> 2. **Security** — injection, auth bypass, data exposure
> 3. **Patterns** — does the code follow existing codebase conventions?
> 4. **File responsibility** — does each file have one clear responsibility?
>
> Do NOT flag: style preferences, naming nitpicks, missing docs, test coverage opinions.
>
> Report:
> - **PASS** — no obvious issues (brief confirmation)
> - **FAIL** — [specific issues with file:line references]

## Model

Always sonnet. This is a brief quality check, not a full audit. The full review happens against the PR in `/review`.

## Fix Loop

If FAIL: re-dispatch the implementer with the review feedback, then re-run this review. Max 2 re-dispatches (3 total attempts including initial).
