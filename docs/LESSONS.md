# Lessons

A log of every slip and lesson from running the review/implement loop so far. It is seeded from the merged skill-lesson PRs (#6, #9, #13 and #22) and their review threads. "Who" is a role, not a session. Anything GitHub doesn't show is marked "(manager's account)". Numbers like 4503791833 are review comment IDs on the cited PR. All dates are 2026-11-07, the day the loop has run so far.

## How to use

- **After every merge,** add any new slip here and add the PR's rows to [`METRICS.md`](METRICS.md). Update "Recurred after the fix" when a logged slip shows up again.
- **A slip seen twice gets a skill fix immediately,** in its own small PR, instead of waiting for the next batch of lessons.
- Word each slip generically so it applies to any repo, and cite the evidence on GitHub.

## Log

| Date | Slip | Who | Skill or doc fix | Fixed in | Recurred after the fix |
| --- | --- | --- | --- | --- | --- |
| 2026-11-07 | Reported deleting review comments that were never deleted (manager's account; the comments aren't on GitHub). | Reviewer | "Trust only what's verified" principle in `WAY_OF_WORKING.md`; the manager checks every report on GitHub (`pr-review-loop`, loop steps 2 and 4). | #4 | Not seen on GitHub. |
| 2026-11-07 | Shipped a security guard that a reviewer could bypass (joined flags, write-then-post race, `&` race), found on #4. | Implementer | Guard shipped as a file with tests for every reproduced bypass; reviewers must try to break security code and report only bypasses they reproduced (`pr-inline-review`). | #6 | Yes: #26 (open) has five new reproduced bypasses, including 4503954735, which is already on master. |
| 2026-11-07 | A test case passed for the wrong reason: the hook blocked it for a different cause than the one under test (#6, 4503721273 and 4503721293). | Implementer | Test before pushing and list each security test with its result (`pr-address-review`). | #6 | Yes: #24, 4503904403 (an expected failure not tied to its cause). |
| 2026-11-07 | A reviewer dropped a concern the brief asked about (manager's account). | Reviewer | Address every concern the brief raises (`pr-inline-review`). | #6 | Not seen on GitHub. |
| 2026-11-07 | A review post was blocked by permissions and the draft was at risk of being lost (manager's account). | Reviewer | Write the review to a file and post it as a standalone command; when blocked, report the draft's path; the manager posts checked drafts (`pr-inline-review`, `pr-review-loop`). | #6 | Not seen on GitHub. |
| 2026-11-07 | Overstated how the guard hook treats chained commands: claimed it blocks every chain that touches reviews (#9, 4503791833). | Manager | Rules in `pr-review-loop` describe exactly which chains are blocked. | #9 | Yes, once, inside #9: the same claim remained in another file (4503801236) and was fixed in the same PR. Not seen since. |
| 2026-11-07 | Started sessions in new worktrees without the untracked local settings, so they ran without the guard hook (#9, 4503791822). | Manager | First a note in "Parallel pairs" (#9). Then a "Worktrees" section: copy the settings in and prove the guard runs with a probe before starting (#13). | #9, #13 | Yes: #13, 4503831185 (checking that the file exists doesn't prove the guard runs). Fixed in #13; not seen since. |
| 2026-11-07 | A PR opened before CI existed was about to merge without CI having run (we updated #8 from master). | Manager | Finish in `pr-review-loop`: `gh pr update-branch` before the last round, review the new head, tell implement to pull. | #9 | Not seen since. |
| 2026-11-07 | Nothing stopped a reviewer from labelling a security problem a nit (#13, 4503831194). | Reviewer | Severity labels with a floor for security findings (`pr-inline-review`); only must-fix keeps the loop going (`pr-review-loop`). | #13 | Not seen since. |
| 2026-11-07 | Branched from a stale local default branch instead of a freshly fetched `origin/master` (twice, per the #22 description). | Implementer | Run `git fetch` first and branch from `origin/<default>` (`pr-address-review`). | #22 | Not seen since. |
| 2026-11-07 | Cited PR numbers as evidence for claims GitHub doesn't show (#16, 4503867801). | Implementer | Cite evidence GitHub still shows, and mark claims that rest on someone's account (`pr-inline-review`). | #22 | Not seen since. |
| 2026-11-07 | Session titles didn't say which pair or task they were on (manager's account). | Manager | Rename both sessions to `<handle>: <task>` when a pair takes a new task (`pr-review-loop`). | #22 | Not seen since. |
| 2026-11-07 | Started another parallel pair with too little disk free, and a session failed to start (manager's account). | Manager | Check free disk space before starting another pair, and clean up right after each merge (`pr-review-loop`). | #22 | Not seen since. |
| 2026-11-07 | A doc change contradicted another doc or another step: `AGENTS.md` on #13 (4503850035), and step order on #22 (4503883577). | Implementer | None yet. Each was fixed in its own PR. | — | Yes: #13, then #22. Seen twice, so by the rule above this needs a skill fix (for example, "grep the other docs for the rule you change"). |
