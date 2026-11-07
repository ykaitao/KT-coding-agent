---
name: pr-address-review
description: Address inline review comments on a GitHub pull request by editing the PR branch, pushing, and replying in each thread. Use when asked to fix or implement review feedback in an implement/review loop.
---

# Address PR review comments

## Steps
1. Read the comments: `gh api repos/<owner/repo>/pulls/<n>/comments --jq '.[] | {id, line, path, body, in_reply_to_id}'`. Work only on top-level comments that have no reply from you yet.
2. Check out the PR branch (don't switch to any other). Make the smallest edit that addresses each comment, and apply `suggestion` blocks as given unless they're wrong (if so, say why in your reply).
3. Touch only the files the comments concern. Never stage unrelated local changes; use `git add <path>`, never `git add -A`.
4. Commit with a clear message, adding any attribution trailer the environment requires, and push to the PR branch.
5. Reply in each thread with how it was addressed and the commit SHA: `gh api repos/<owner/repo>/pulls/<n>/comments/<id>/replies -f body=...`.
6. Verify: re-fetch the PR and confirm the head SHA and that every reply landed. Never report an action you haven't verified.

## Rules
- Do not resolve threads, approve, or merge.
- No bare `@mentions`.

## Report
The commit SHA, plus one line per comment saying what changed.
