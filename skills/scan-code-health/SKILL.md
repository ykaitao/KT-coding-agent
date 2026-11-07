---
name: scan-code-health
description: Read-only scan of a named path or glob for code-health problems (correctness bugs, dead or duplicated code, missing error handling), written as one Markdown report of evidence-backed findings. Use when asked to scan code for health issues; not for PR review.
---

# Scan code health

Read-only. The only file you write is the report, at the path the user names; don't commit it. Don't edit other files, commit, push, open issues or PRs, or post comments anywhere. Run only the project's own local tests or linters, and nothing that pushes or posts.

## Input
- A repository checkout.
- A **path or glob to scan**, named by the user (for example `src/billing/` or `lib/**/*.js`). Don't pick the scope yourself. If none is given, ask.
- A **report path** to write to, named by the user. If none is given, ask.

## What to look for
The skill isn't tied to one language: apply the same checks to whatever languages the scanned files use, in that language's terms. Only the code-health dimension:
- **Correctness bugs:** wrong conditions, off-by-one errors, unhandled edge cases (empty input, null or `None`, zero), shared mutable state, wrong return values.
- **Dead code:** functions, branches or variables that nothing reaches or uses. Confirm with a search across the repo, not just the scanned path.
- **Duplicated code:** logic repeated closely enough that a fix to one copy would need the same fix in another.
- **Missing error handling:** errors swallowed silently (for example a bare `except: pass` in Python, or a `catch` that discards the error in JavaScript), and resources or calls that fail with no handling where a caller would need it.

Leave out style, naming, formatting, architecture, performance, cost, security and accessibility. Those are other dimensions.

## Steps
1. List the files matching the path or glob, and read each one in full.
2. If the project has its own tests or linters, you may run them and use their output as evidence. Don't install or add new tools.
3. Note candidate findings as you read.
4. **Verify each candidate before reporting it.** Re-read the file at the cited line and confirm it holds the code you're quoting. Back the claim with either the quoted line or lines, or a command you ran and its output (for example a search showing nothing calls a function, or a one-line run that raises the error). If you can't back it, drop it.
5. Write the report.

## Report format
One Markdown file at the report path. The example finding is JavaScript; a Python finding looks the same, with a `python` code block and a Python command. Use this structure exactly: the headings, field labels and their order are fixed, because later steps parse them.

````markdown
# Code-health scan: <path or glob>

Scanned at commit <short SHA> on <date>. Files scanned: <n>.

## Findings (<count>)

### 1. <one-line claim>
- **File:** `src/stats.js:42`
- **Severity:** high | medium | low
- **Evidence:**
  ```javascript
  return total / scores.length;
  ```
  `average([])` returns `NaN`: `node -e "console.log(require('./src/stats').average([]))"` prints `NaN`.
````

Severity:
- **high:** wrong results, crashes or lost data on realistic input.
- **medium:** errors swallowed or hidden, or a likely future bug, such as duplicated logic that has already drifted apart.
- **low:** dead code or duplication with no current wrong behaviour.

If there are no findings, the report says `## Findings (0)` and the line `No code-health findings in <path or glob>.` Never pad the report.

## Rules
- Read-only: the report is the only file you write. No other edits, commits, pushes, issues, PRs or comments.
- Every finding has a file, a line, a severity, a claim and evidence. A finding without evidence is dropped, not softened.
- Report only what you verified. Don't claim the scan is complete or that the code is free of bugs.

## Report back
The report path, the number of findings by severity, and the files scanned.
