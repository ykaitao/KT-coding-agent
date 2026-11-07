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

skill() { # skill <dir> <folder> <name> <description> [body]
  mkdir -p "$1/$2"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n%s\n' "$3" "$4" "${5:-Body.}" > "$1/$2/SKILL.md"
}
run() { # run <user dirs> [options...]: prints output, sets $code
  local dirs=$1; shift
  out="$(bash "$script" --repo-skills "$tmp/repo" --user-dirs "$dirs" "$@" 2>&1)"; code=$?
}

skill "$tmp/repo" pr-review-loop pr-review-loop "Run alternating review and implement rounds on a pull request until a review is clean."
skill "$tmp/repo" scan-code-health scan-code-health "Read-only scan of a named path for code-health problems, written as an evidence-backed report."

# 1. Clean: an unrelated user skill, even with a similar description.
skill "$tmp/home1/.claude/skills" deploy-notes deploy-notes "Draft release notes from merged changelog entries for a deploy."
skill "$tmp/home1/.claude/skills" review-rounds review-rounds "Run alternating review and implement rounds on a pull request until the review is clean."
run "$tmp/home1/.claude/skills"
check "clean: exit 0" [ "$code" -eq 0 ]
check "clean: no warnings, similar wording isn't reported" [ -z "$(grep '^WARN' <<<"$out")" ]
check "clean: summary counts" grep -q "2 repo skills, 1 user folders, 0 same-name" <<<"$out"

# 2. Same name in ~/.claude/skills: warned, Claude Code's winner named, exit 0 (1 with --strict).
skill "$tmp/home2/.claude/skills" pr-review-loop pr-review-loop "My own loop." "SECRET-BODY-TEXT"
run "$tmp/home2/.claude/skills"
check "collision: exit 0 by default" [ "$code" -eq 0 ]
check "collision: warned with both paths" grep -q "WARN same name (folder and name): pr-review-loop: $tmp/home2/.claude/skills/pr-review-loop and $tmp/repo/pr-review-loop" <<<"$out"
check "collision: Claude Code winner named" grep -q "Claude Code loads the personal copy" <<<"$out"
check "collision: body never printed" [ -z "$(grep 'SECRET-BODY-TEXT' <<<"$out")" ]
check "collision: description never printed" [ -z "$(grep 'My own loop' <<<"$out")" ]
run "$tmp/home2/.claude/skills" --strict
check "collision: --strict exits 1" [ "$code" -eq 1 ]

# 3. Same name in ~/.agents/skills: Codex and Copilot wording.
skill "$tmp/home3/.agents/skills" scan-code-health scan-code-health "Mine."
run "$tmp/home3/.agents/skills"
check "agents collision: Codex shows both, Copilot undocumented" grep -q "Codex doesn't merge them, so both copies can appear; Copilot's rule isn't documented" <<<"$out"

# 4. A folder no provider documents (~/.codex/skills) is labelled as such.
skill "$tmp/home4/.codex/skills" pr-review-loop pr-review-loop "Mine."
run "$tmp/home4/.codex/skills"
check "codex folder: labelled undocumented" grep -q "not a documented skills folder for Claude Code, Codex or Copilot" <<<"$out"
check "codex folder: no Codex behaviour claimed" [ -z "$(grep 'Codex doesn' <<<"$out")" ]

# 5. Missing user folders and a link back to the repo's own skill are not conflicts.
mkdir -p "$tmp/home5/.claude/skills"
ln -s "$tmp/repo/pr-review-loop" "$tmp/home5/.claude/skills/pr-review-loop"
run "$tmp/nowhere/.claude/skills:$tmp/home5/.claude/skills"
check "links and missing folders: no warnings" [ -z "$(grep '^WARN' <<<"$out")" ]
check "links and missing folders: exit 0" [ "$code" -eq 0 ]

# 6. KT_SKILLS_USER_DIRS sets the default folders.
out="$(KT_SKILLS_USER_DIRS="$tmp/home2/.claude/skills" bash "$script" --repo-skills "$tmp/repo" 2>&1)"
check "env default: collision found" grep -q "WARN same name (folder and name): pr-review-loop" <<<"$out"

# 7. Unclosed frontmatter: the body is never read, so a body line can't become the name.
mkdir -p "$tmp/home7/.claude/skills/my-notes"
printf -- '---\ndescription: x\n\nBODY-SENTINEL line\nname: pr-review-loop\n' > "$tmp/home7/.claude/skills/my-notes/SKILL.md"
run "$tmp/home7/.claude/skills"
check "unclosed frontmatter: no warning from a body line" [ -z "$(grep '^WARN' <<<"$out")" ]
check "unclosed frontmatter: body never printed" [ -z "$(grep 'BODY-SENTINEL' <<<"$out")" ]

# 8. Folder name matches even when the frontmatter name differs; two such folders are both reported.
skill "$tmp/home8/.claude/skills" pr-review-loop other "Mine."
skill "$tmp/home8/.claude/skills" my-copy scan-code-health "Mine."
skill "$tmp/home8/.claude/skills" my-second-copy scan-code-health "Mine."
run "$tmp/home8/.claude/skills"
check "folder match: reported" grep -q "WARN same name (folder): pr-review-loop: $tmp/home8/.claude/skills/pr-review-loop" <<<"$out"
check "name match: first folder reported" grep -q "WARN same name (name): scan-code-health: $tmp/home8/.claude/skills/my-copy " <<<"$out"
check "name match: second folder reported" grep -q "WARN same name (name): scan-code-health: $tmp/home8/.claude/skills/my-second-copy " <<<"$out"
check "folder and name matches: counted" grep -q " 3 same-name" <<<"$out"

# 9. Bad options give a usage error with exit 2, never a traceback.
run "$tmp/home1/.claude/skills" --threshold abc
check "bad option: exit 2" [ "$code" -eq 2 ]
check "bad option: usage printed" grep -q "^usage:" <<<"$out"
check "bad option: no traceback" [ -z "$(grep 'Traceback' <<<"$out")" ]
out="$(bash "$script" --repo-skills 2>&1)"; code=$?
check "missing value: exit 2" [ "$code" -eq 2 ]

exit "$fail"
