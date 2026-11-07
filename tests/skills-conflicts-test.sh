#!/usr/bin/env bash
# Tests for tests/skills-conflicts.sh, using scratch skill folders only (never the real ~/ ones).
# Run from anywhere: bash tests/skills-conflicts-test.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd -P)"
script="${SKILLS_CONFLICTS:-$root/tests/skills-conflicts.sh}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
check() { local what=$1; shift; if "$@"; then ok "$what"; else bad "$what"; fi; }

skill() { # skill <dir> <name> <description> [body]
  mkdir -p "$1/$2"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n%s\n' "$2" "$3" "${4:-Body.}" > "$1/$2/SKILL.md"
}
run() { # run <user dirs> [options...]: prints output, sets $code
  local dirs=$1; shift
  out="$(bash "$script" --repo-skills "$tmp/repo" --user-dirs "$dirs" "$@" 2>&1)"; code=$?
}

skill "$tmp/repo" pr-review-loop "Run alternating review and implement rounds on a pull request until a review is clean."
skill "$tmp/repo" scan-code-health "Read-only scan of a named path for code-health problems, written as an evidence-backed report."

# 1. Clean: an unrelated user skill.
skill "$tmp/home1/.claude/skills" deploy-notes "Draft release notes from merged changelog entries for a deploy."
run "$tmp/home1/.claude/skills"
check "clean: exit 0" [ "$code" -eq 0 ]
check "clean: no warnings" [ -z "$(grep '^WARN' <<<"$out")" ]
check "clean: summary counts" grep -q "2 repo skills, 1 user folders, 0 same-name, 0 similar" <<<"$out"

# 2. Same name in ~/.claude/skills: warned, Claude Code's winner named, exit 0 (1 with --strict).
skill "$tmp/home2/.claude/skills" pr-review-loop "My own loop." "SECRET-BODY-TEXT"
run "$tmp/home2/.claude/skills"
check "collision: exit 0 by default" [ "$code" -eq 0 ]
check "collision: warned with both paths" grep -q "WARN same name: pr-review-loop: $tmp/home2/.claude/skills/pr-review-loop and $tmp/repo/pr-review-loop" <<<"$out"
check "collision: Claude Code winner named" grep -q "Claude Code loads the personal copy" <<<"$out"
check "collision: body never printed" [ -z "$(grep 'SECRET-BODY-TEXT' <<<"$out")" ]
check "collision: description never printed" [ -z "$(grep 'My own loop' <<<"$out")" ]
run "$tmp/home2/.claude/skills" --strict
check "collision: --strict exits 1" [ "$code" -eq 1 ]

# 3. Same name in ~/.agents/skills: Codex and Copilot wording.
skill "$tmp/home3/.agents/skills" scan-code-health "Mine."
run "$tmp/home3/.agents/skills"
check "agents collision: Codex shows both, Copilot undocumented" grep -q "Codex shows both copies; Copilot's rule isn't documented" <<<"$out"

# 4. Near-duplicate description under another name: warned with a score, exit 0 even with --strict.
skill "$tmp/home4/.codex/skills" review-rounds "Run alternating review and implement rounds on a pull request until the review is clean, then report."
run "$tmp/home4/.codex/skills" --strict
check "near-duplicate: warned" grep -q "WARN similar description (0\.[0-9][0-9]): review-rounds" <<<"$out"
check "near-duplicate: --strict still exits 0" [ "$code" -eq 0 ]
run "$tmp/home4/.codex/skills" --threshold 0.99
check "near-duplicate: a higher threshold silences it" [ -z "$(grep '^WARN' <<<"$out")" ]

# 5. Missing user folders and a link back to the repo's own skill are not conflicts.
mkdir -p "$tmp/home5/.claude/skills"
ln -s "$tmp/repo/pr-review-loop" "$tmp/home5/.claude/skills/pr-review-loop"
run "$tmp/nowhere/.claude/skills:$tmp/home5/.claude/skills"
check "links and missing folders: no warnings" [ -z "$(grep '^WARN' <<<"$out")" ]
check "links and missing folders: exit 0" [ "$code" -eq 0 ]

# 6. KT_SKILLS_USER_DIRS sets the default folders.
out="$(KT_SKILLS_USER_DIRS="$tmp/home2/.claude/skills" bash "$script" --repo-skills "$tmp/repo" 2>&1)"
check "env default: collision found" grep -q "WARN same name: pr-review-loop" <<<"$out"

exit "$fail"
