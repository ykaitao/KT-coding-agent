---
name: code-test-design
description: Review the tests for a named piece of code and report the gaps, each proven: behaviours with no test, missing edge cases, tests that pass for the wrong reason (shown by a mutation that still passes), and flaky patterns. Use when asked to check test coverage or test quality for a change or a module; read-only.
---

# Test design review

You are the QA role: you work for the manager, and you report gaps rather than fix them. Read-only. The only file you write is the report, plus scratch copies for mutation runs outside the repo; don't commit, push or post anything.

## Input
- A repository checkout at a named commit.
- The code under test and its tests, as paths the user names. If they aren't named, ask.
- The acceptance criteria, if any (for example from `repo-spec-write`). Each criterion should map to at least one test.
- A report path.

## What to look for
The skill isn't tied to one language. Apply the same checks in the terms of the code's language and test framework.
- **Untested behaviour:** a branch, case or public function that no test runs.
- **Missing edge case:** a tested behaviour whose limits aren't tested, such as empty input, the exact boundary value, or a repeated action. Report it only where the code makes the case matter.
- **Wrong reason:** a test that passes, but would still pass if the code were wrong. Examples: it asserts only that a value is truthy, it ignores the return value, or it checks the input instead of the output.
- **Flaky pattern:** a result that can change between runs: the real clock or `sleep`, randomness, network or file state, or tests that depend on each other's order or shared state.

Leave out style, speed and code bugs that a test already catches. For code bugs with no test, `scan-code-health` is the scanner; report here only the missing test.

## Steps
1. Read the code and its tests in full. Run the tests with the project's own command, and note the result.
2. Map each behaviour (branch, case, public function, acceptance criterion) to the tests that cover it.
3. Note candidate findings.
4. **Prove each one before reporting it:**
   - **Wrong reason:** make a mutant. Copy the code to a scratch folder outside the repo, change one line so the behaviour is wrong (for example return the input unchanged), and run the test against it. If the test still passes, report the mutant and the run. If it fails, drop the finding.
   - **Untested behaviour:** show that no test calls it, with a search or by mapping the tests.
   - **Missing edge case:** name the exact input, and say what the code does with it today.
   - **Flaky pattern:** quote the line that depends on time, randomness, order or shared state, and say how it can flip.
   - **Line numbers:** confirm every `file:line` by printing it (for example `sed -n '<n>p' <file>`), and quote it exactly.
5. Write the report. For each finding, propose a test: its input and its expected result.

## Report format
Use this structure exactly. The headings, field labels and their order are fixed, because later steps parse them.

````markdown
# Test design review: <code path> and <test path>

Reviewed at commit <short SHA> on <date>. Test command: `<command>`, result: <passed/failed counts>.

## Findings (<count>)

### 1. <one-line claim>
- **File:** `tests/test_orders.py:12`
- **Class:** untested behaviour | missing edge case | wrong reason | flaky
- **Severity:** high | medium | low
- **Evidence:** the quoted line, and for a wrong reason the mutant and its passing run.
- **Proposed test:** given <input>, expect <result>.
````

The **File** of a finding about an existing test is that test's line. For an untested behaviour or a missing edge case, it's the line of code that lacks the test.

Severity:
- **high:** a wrong-reason test, or untested behaviour that can lose data, money or access.
- **medium:** a flaky test, or untested behaviour or a missing edge case on a main path.
- **low:** everything else.

If there are no findings, the report says `## Findings (0)` and the line `No test design gaps in <paths>.` Never pad the report.

## Rules
- Read-only, except for the report and scratch mutants outside the repo.
- Every finding has a file, a line, a class, a severity, evidence and a proposed test. A "wrong reason" finding without a mutant that passes is dropped.
- Don't claim the tests are complete. Report only what you proved.

## Report back
The report path, the counts by class and severity, the test command and its result, and anything you couldn't run.
