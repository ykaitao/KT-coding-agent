---
name: github-markdown-editing
description: Safely create or edit GitHub issue and pull-request comments, descriptions, and review text with correctly rendered Markdown. Use whenever posting or editing Markdown through GitHub CLI, API, or browser automation.
---

# GitHub Markdown Editing

Use this workflow whenever writing Markdown to GitHub (issue/PR descriptions, comments, reviews, or discussion replies). The same instructions are intentionally compatible with Claude Code and Codex.

## Draft first

1. Draft the complete body as a UTF-8 string before invoking a GitHub write operation.
2. Preserve Markdown source literally: real newline characters for line breaks, backticks for inline code, and blank lines around headings, paragraphs, lists, and fenced code blocks.
3. Avoid shell interpolation. Backticks can execute as command substitution in shells, and JSON escaping can accidentally turn newlines into literal `\\n`. Do not place a long Markdown body directly inside a shell double-quoted argument.
4. Prefer a JSON request file passed with `gh api --input <file>` (or the equivalent safe API/client request body). Serialize with a real JSON encoder; do not manually escape the document. For `gh issue comment`, use a safely written temporary body file and `--body-file` when available.
5. Do not use shell here-docs, `echo`, or `printf` to construct bodies when interpolation/escape behavior could alter Markdown. Use the environment's normal file-editing facility or a JSON serializer. Keep secrets out of drafts and temporary files.

## Validate before posting

Inspect the exact serialized/request body and check:

- Headings are separated from surrounding content by blank lines.
- Lists have a blank line before them and each item begins on its own line.
- Inline code still has matching backticks; fenced blocks use matching fences and specify a language when useful.
- Links use `[descriptive text](https://...)`, with balanced brackets/parentheses and direct destination URLs.
- There are no literal `\\n` sequences where paragraph breaks were intended, no missing code spans, no accidental shell-expanded text, and no unintended trailing whitespace.
- Unicode punctuation, non-ASCII text, and currency symbols are intact.
- The body is concise, factually checked, and appropriate for the target issue/PR. If it includes volatile facts such as prices or product behavior, verify and date/qualify them.

If a local Markdown linter/parser is available, run it against the draft. A linter supplements, but does not replace, inspection of the exact body.

## Write and verify

1. Resolve the exact repository, issue/PR, and comment ID before editing. Preserve unrelated text and do not create duplicate comments when editing is intended.
2. Submit the body through a safely encoded request. For example, create JSON with a proper serializer and use `gh api repos/OWNER/REPO/issues/comments/ID --method PATCH --input body.json`.
3. Fetch the edited resource again and inspect its returned `body`. Confirm it contains actual newlines and intact Markdown delimiters. Do not treat a successful HTTP response alone as proof that formatting is correct.
4. When possible, open the GitHub web page and visually check the rendered result. If the API body is correct but rendering is not, inspect for Markdown structure errors and fix the same comment.
5. Report the edited URL and briefly state what was verified. Never claim visual verification unless the rendered page was actually inspected.

## Recovery

If formatting was corrupted, edit the existing comment rather than adding another. Reconstruct the intended body, safely serialize it, patch the exact comment, then fetch and verify again. If the wrong comment/target was edited, stop and explain before making a broader change.

