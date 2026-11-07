# Expected spec content for the repo-spec-write fixtures

Each fixture is a vague request (`REQUEST.md`) plus the code it concerns. A spec written with the `repo-spec-write` skill should contain the items below. Match by meaning, not wording.

Item kinds:
- **criterion:** an observable acceptance criterion. At least one per fixture must fail on today's code.
- **evidence:** a cited `file:line` (or a command and its output) showing today's behaviour.
- **question:** an open question for the owner, not a decision the spec makes on its own.
- **must not:** something the spec must not state as a requirement or fact.

## `python/` (login lockout)

| Kind | Expected | Line |
| --- | --- | --- |
| evidence | `is_locked` uses `count > MAX_ATTEMPTS`, so a 6th failed attempt is still allowed ("could keep guessing") | 17 |
| evidence | failures are never cleared: `WINDOW_SECONDS` and `first` are unused, so a lockout never expires ("locked out for good") | 4, 11–12, 16 |
| evidence | `record_success` does nothing, so a successful login doesn't reset the count | 20–21 |
| criterion | after 5 failed attempts within the window, the next attempt is rejected (fails today) | |
| criterion | once the window has passed since the first failure, the user can try again (fails today) | |
| criterion | a successful login resets the failure count (fails today) | |
| question | the intended limit and window, or whether 5 attempts and 15 minutes are right | |
| question | at least one of: lock per user, per IP or both; and what the user is told when locked | |
| must not | add CAPTCHA, email alerts or account unlock flows as requirements (they're not in the request or the code) | |

## `javascript/` (CSV export)

| Kind | Expected | Line |
| --- | --- | --- |
| evidence | values are joined with `,` without quoting, so a value containing a comma (or quote or newline) shifts columns | 6 |
| evidence | an empty list returns `""`, so the file has no header | 2–4 |
| evidence | the header comes from the first row's keys and values from `Object.values`, so rows with different key order or missing keys misalign | 5–6 |
| criterion | a value containing a comma, a double quote or a newline appears in a single column when opened (quoted and escaped, as in RFC 4180) (fails today) | |
| criterion | exporting an empty report gives a file with the header row (fails today), or the spec raises this as a question because the columns aren't known | |
| criterion | each value lands under its own header even when rows list keys in a different order (fails today) | |
| question | at least one of: the line ending (`\n` or `\r\n`), the column order and names for an empty report, or the target spreadsheet | |
| must not | state an encoding, delimiter change or Excel-specific requirement as fact (not in the request) | |
