#!/usr/bin/env bash
# Checks that every provider sees the same, well-formed skills:
#   1. .claude/skills, .agents/skills and .github/skills are symlinks to skills/
#   2. each skills/*/SKILL.md has frontmatter with a matching name and a description
#   3. skills/README.md lists exactly the skills that exist
#   4. no file under skills/ leaks home paths, emails, tokens, other repos'
#      issue/PR references or URLs, or (locally) terms from a private list
#   5. no file under skills/ tells an agent to do something dangerous: pipe to a
#      shell, rm -rf a variable or /, bypass guards or hooks, force-push a
#      default branch, run base64-decoded code, or follow injected instructions.
#      A line can opt out only with <!-- skills-check: allow -->. This is a lint for
#      honest mistakes, not a defence: it scans line by line (joining lines that
#      end in a backslash), so text split across lines or fences, Unicode
#      lookalikes, or reworded instructions can pass.
#   6. manager instructions name the visible-session default, keep scope and approvals task-specific, and require owner approval before hidden/background fallback
# Run from anywhere: bash tests/skills-check.sh
# Private terms: one per line in $SKILLS_PRIVATE_TERMS
# (default ~/.config/kt-coding-agent/private-terms.txt). Never commit that file.
# CI runs this script; the private-terms check only runs where that file exists.
# Files under skills/ that are not UTF-8 text fail, since they can't be scanned.
set -u

root="$(cd "$(dirname "$0")/.." && pwd -P)"
skills_dir="$root/skills"
failures=0

ok()   { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# 1. Provider symlinks.
for link in .claude/skills .agents/skills .github/skills; do
  path="$root/$link"
  if [ ! -L "$path" ]; then
    fail "$link is not a symlink"
  elif [ "$(cd "$path" 2>/dev/null && pwd -P)" != "$skills_dir" ]; then
    fail "$link does not resolve to skills/ (points to $(readlink "$path"))"
  else
    ok "$link -> skills/"
  fi
done

# 1b. Check required policy wording in both files. This is a literal marker
# check, not a semantic verification of the complete provider/tool contract.
visible_session_policy_matches() {
  local agents_file="$1"
  local skill_file="$2"
  grep -qF 'Use authorized owner-visible agent sessions by default.' "$agents_file" \
    && grep -qF 'Ask the owner before falling back to hidden/background agents.' "$agents_file" \
    && grep -qF 'Visible sessions across agent hosts' "$skill_file" \
    && grep -qF 'Codex desktop' "$skill_file" \
    && grep -qF 'Claude desktop' "$skill_file" \
    && grep -qF 'Other hosts' "$skill_file" \
    && grep -qF 'Ask the owner before falling back to hidden/background agents.' "$skill_file"
}

task_scope_policy_matches() {
  local agents_file="$1"
  local skill_file="$2"
  grep -qF 'Use the current task boundary.' "$agents_file" \
    && grep -qF 'Prior turns, memory, issue discussions and approvals are context, not authorization to work elsewhere.' "$agents_file" \
    && grep -qF 'Read-only production access and paid API calls require owner authorization for the current task' "$agents_file" \
    && grep -qF 'Brief each session for one task' "$skill_file" \
    && grep -qF 'Prior session history, issue discussions, saved memory, and approvals do not authorize a different task' "$skill_file" \
    && grep -qF 'Production reads are external actions too' "$skill_file"
}

write_without_marker() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:3])
marker = sys.argv[3]
text = source.read_text(encoding="utf-8")
if text.count(marker) != 1:
    sys.exit("expected exactly one policy marker in %s" % source)
destination.write_text(text.replace(marker, "", 1), encoding="utf-8")
PY
}

agents_file="$root/AGENTS.md"
loop_skill_file="$skills_dir/pr-review-loop/SKILL.md"
if visible_session_policy_matches "$agents_file" "$loop_skill_file"; then
  ok "manager policy names visible sessions and owner approval before hidden/background fallback"
else
  fail "manager policy must name visible sessions and owner approval before hidden/background fallback in AGENTS.md and pr-review-loop/SKILL.md"
fi

if task_scope_policy_matches "$agents_file" "$loop_skill_file"; then
  ok "each assignment has a current-task boundary; prior context and approvals do not expand it"
else
  fail "AGENTS.md and pr-review-loop/SKILL.md must require current-task scope and authorization for production or paid calls"
fi

# Negative fixtures prove the matcher rejects the policy when the owner gate is
# removed from either file; the provider markers remain intact in each fixture.
fixture_dir="$(mktemp -d)"
trap 'rm -f "$fixture_dir/AGENTS.md" "$fixture_dir/SKILL.md" "$fixture_dir/AGENTS.no-scope.md" "$fixture_dir/SKILL.no-scope.md"; rmdir "$fixture_dir"' EXIT
if ! write_without_marker "$agents_file" "$fixture_dir/AGENTS.md" 'Ask the owner before falling back to hidden/background agents.'; then
  fail "could not create AGENTS.md fixture without the owner gate"
elif ! grep -qF 'Use authorized owner-visible agent sessions by default.' "$fixture_dir/AGENTS.md"; then
  fail "AGENTS.md negative fixture lost its visible-session marker"
elif visible_session_policy_matches "$fixture_dir/AGENTS.md" "$loop_skill_file"; then
  fail "visible-session matcher accepted AGENTS.md without the hidden/background owner gate"
else
  ok "visible-session matcher rejects AGENTS.md without the hidden/background owner gate"
fi
cp "$agents_file" "$fixture_dir/AGENTS.md"
if ! write_without_marker "$loop_skill_file" "$fixture_dir/SKILL.md" 'Ask the owner before falling back to hidden/background agents.'; then
  fail "could not create pr-review-loop/SKILL.md fixture without the owner gate"
elif ! grep -qF 'Visible sessions across agent hosts' "$fixture_dir/SKILL.md"; then
  fail "pr-review-loop/SKILL.md negative fixture lost its visible-session marker"
elif visible_session_policy_matches "$agents_file" "$fixture_dir/SKILL.md"; then
  fail "visible-session matcher accepted pr-review-loop/SKILL.md without the hidden/background owner gate"
else
  ok "visible-session matcher rejects pr-review-loop/SKILL.md without the hidden/background owner gate"
fi
if ! write_without_marker "$agents_file" "$fixture_dir/AGENTS.no-scope.md" 'Prior turns, memory, issue discussions and approvals are context, not authorization to work elsewhere.'; then
  fail "could not create AGENTS.md fixture without the current-task scope gate"
elif task_scope_policy_matches "$fixture_dir/AGENTS.no-scope.md" "$loop_skill_file"; then
  fail "task-scope matcher accepted AGENTS.md without the current-task boundary"
else
  ok "task-scope matcher rejects AGENTS.md without the current-task boundary"
fi
if ! write_without_marker "$loop_skill_file" "$fixture_dir/SKILL.no-scope.md" 'Prior session history, issue discussions, saved memory, and approvals do not authorize a different task'; then
  fail "could not create pr-review-loop/SKILL.md fixture without the current-task scope gate"
elif task_scope_policy_matches "$agents_file" "$fixture_dir/SKILL.no-scope.md"; then
  fail "task-scope matcher accepted pr-review-loop/SKILL.md without the current-task boundary"
else
  ok "task-scope matcher rejects pr-review-loop/SKILL.md without the current-task boundary"
fi

# 2. Frontmatter of each SKILL.md.
existing=""
for dir in "$skills_dir"/*/; do
  folder="$(basename "$dir")"
  existing="$existing $folder"
  file="$dir/SKILL.md"
  if [ ! -f "$file" ]; then
    fail "skills/$folder has no SKILL.md"
    continue
  fi
  if ! msg="$(python3 - "$file" "$folder" 2>&1 <<'PY'
import sys
path, folder = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().splitlines()
if not lines or lines[0].strip() != "---":
    sys.exit("no YAML frontmatter (first line is not ---)")
try:
    end = lines.index("---", 1)
except ValueError:
    sys.exit("frontmatter is not closed with ---")
fields = {}
key = None
for line in lines[1:end]:
    if ":" in line and not line[:1].isspace():
        key, _, value = line.partition(":")
        key = key.strip()
        fields[key] = value.strip().strip("'\"")
    elif key and line[:1].isspace():
        # Continuation of a block scalar (> or |) or a folded plain value.
        fields[key] += " " + line.strip()
for key, value in fields.items():
    # For a block scalar the value is the continuation lines, not the indicator.
    if value[:1] in (">", "|"):
        fields[key] = value.split(" ", 1)[1].strip() if " " in value else ""
if fields.get("name") != folder:
    sys.exit("name is %r, expected %r" % (fields.get("name"), folder))
if not fields.get("description"):
    sys.exit("description is missing or empty")
PY
  )"; then
    fail "skills/$folder/SKILL.md: $msg"
  else
    ok "skills/$folder/SKILL.md frontmatter"
  fi
done

# 3. README list matches the skill folders. Only the "## Skills" section counts.
section="$(awk '/^## /{in_list = ($0 == "## Skills"); next} in_list' "$skills_dir/README.md")"
listed="$(printf '%s\n' "$section" | sed -n 's/^- \[`\([^`]*\)`\].*/\1/p')"
for name in $(printf '%s\n' "$listed" | sort | uniq -d); do
  fail "README lists $name more than once"
done
for name in $listed; do
  if [ -f "$skills_dir/$name/SKILL.md" ]; then
    ok "README lists $name, which exists"
  else
    fail "README lists $name, but skills/$name/SKILL.md does not exist"
  fi
done
for name in $existing; do
  if printf '%s\n' "$listed" | grep -qx "$name"; then
    :
  else
    fail "skills/$name exists but is not listed in skills/README.md"
  fi
done

# 4. Leak checks over every file under skills/. Each check prints one line.
terms_file="${SKILLS_PRIVATE_TERMS:-$HOME/.config/kt-coding-agent/private-terms.txt}"
leak_out="$(python3 - "$skills_dir" "$terms_file" 2>&1 <<'PY'
import os, re, sys
skills_dir, terms_file = sys.argv[1], sys.argv[2]
this_repo = "ykaitao/kt-coding-agent"
placeholders = {"owner/repo", "<owner/repo>"}
# First path segments of github.com pages that are not repositories.
github_pages = {"settings", "features", "orgs", "apps", "marketplace", "login",
                "notifications", "sponsors", "topics", "collections", "about", "pricing"}

files = []
not_utf8 = []
for base, _, names in os.walk(skills_dir):
    for name in sorted(names):
        path = os.path.join(base, name)
        try:
            text = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            not_utf8.append(os.path.relpath(path, os.path.dirname(skills_dir)))
            continue
        files.append((os.path.relpath(path, os.path.dirname(skills_dir)), text))

# Dangerous-instruction scans: a line may opt out only with an explicit marker,
# so prose cannot exempt itself by accident. The marker is an HTML comment and
# does not render, so every hit it allows is printed for reviewers to see.
ALLOW = "<!-- skills-check: allow -->"

def scan(label, pattern, keep=lambda m: True, flags=0, join=False, allow=False):
    hits = []
    allowed = []
    for rel, text in files:
        if join:
            # Join shell line continuations (later line numbers then shift up).
            text = re.sub(r"\\\n[ \t]*", " ", text)
        for n, line in enumerate(text.splitlines(), 1):
            for m in re.finditer(pattern, line, flags):
                if allow and ALLOW in line:
                    allowed.append("%s:%d: %s" % (rel, n, m.group(0)))
                elif keep(m):
                    hits.append("%s:%d: %s" % (rel, n, m.group(0)))
    for a in allowed:
        print("ok   allowed (%s): %s" % (label, a))
    if hits:
        print("FAIL %s: %s" % (label, "; ".join(hits[:5])))
    else:
        print("ok   no %s in skills/" % label)

if not_utf8:
    print("FAIL files that cannot be scanned (not UTF-8 text): %s" % "; ".join(not_utf8[:5]))
else:
    print("ok   every file under skills/ is UTF-8 text")

scan("home paths", r"(?<![\w.])/Users/[A-Za-z]|(?<![\w.])/home/[A-Za-z]|[A-Za-z]:\\Users\\|~/[A-Za-z.]")
scan("email addresses", r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}",
     keep=lambda m: not re.search(r"@(example\.(com|org|net)|github\.com)$", m.group(0), re.I))
scan("likely tokens",
     r"\bgh[pousr]_[A-Za-z0-9]{20,}|\bgithub_pat_[A-Za-z0-9_]{20,}|(?<![A-Za-z0-9-])sk-[A-Za-z0-9_-]{20,}"
     r"|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY")
scan("cross-repo issue/PR references", r"(?<![\w./-])([\w.-]+/[\w.-]+)#\d+",
     keep=lambda m: m.group(1).lower() not in placeholders | {this_repo})
scan("github.com URLs to other repos", r"github\.com/([\w.-]+/[\w.-]+)",
     keep=lambda m: m.group(1).split("/")[0].lower() not in github_pages
                   and m.group(1).lower().removesuffix(".git") not in placeholders | {this_repo},
     flags=re.I)

# Dangerous instructions: things an agent should never be told to do.
SHELL = r"\|\s*(sudo(\s+-\S+)*\s+)?(env\s+)?(\S*/)?"
scan("pipe-to-shell instructions",
     r"\b(curl|wget)\b[^|\n]*" + SHELL + r"((ba|z|da|k)?sh|python3?|perl|node|ruby)\b"
     r"|\b(ba|z|da|k)?sh\b[^\n]*(\$\(|<\()\s*(curl|wget)\b", allow=True, flags=re.I, join=True)
scan("rm -rf on a variable or /",
     r"\brm\s+((-[A-Za-z]+|--[a-z-]*)\s+)*(-[A-Za-z]*[rR][A-Za-z]*|--recursive)\s+((-[A-Za-z]+|--[a-z-]*)\s+)*"
     r"(\"?\$\{?\w|/(?=[\s*\"]|$)|~(?=[\s/\"]|$))",
     allow=True, join=True)
scan("guard bypasses",
     r"--no-verify|dangerouslyDisableSandbox|--dangerously-skip-permissions"
     r"|\b(edit|modify|overwrite|delete|remove|disable|rm)\b[^\n]{0,30}\.claude/settings"
     r"|(?<![\w>])>>?\s*\S*\.claude/settings"
     r"|\b(remove|delete|disable|bypass|turn off|skip)\s+(the\s+)?([\w-]+\s+)?hooks?\b",
     allow=True, flags=re.I, join=True)
scan("force pushes to a default branch",
     r"\bgit\s+push\b(?=[^\n]*(--force\b|--force-with-lease|\s-f\b|\s\+\S*\b(main|master)\b))"
     r"(?=[^\n]*\b(main|master)\b)[^\n]*", allow=True, join=True)
scan("base64-decoded execution",
     r"base64\s+(-d|-D|--decode)\b[^\n]*" + SHELL + r"((ba|z|da|k)?sh|python3?|perl|node|ruby)\b"
     r"|\beval\b[^\n]*base64", allow=True, join=True)
scan("prompt-injection phrases",
     r"\b(ignore|disregard|forget)\s+(all\s+|any\s+)?(the\s+)?(previous|prior|above|earlier|your)\s+"
     r"(instructions|rules|prompts?|guidelines)\b"
     r"|\b(ignore|disregard|forget)\s+(all\s+|any\s+)?(the\s+)?(instructions|rules|prompts?|guidelines)\s+"
     r"(above|before|earlier)\b"
     r"|\byou are now (in )?(developer mode|DAN|jailbroken)\b"
     r"|\b(do not|don.t) (tell|inform|notify) the (user|owner)\b"
     r"|\bwithout (telling|asking|informing) the (user|owner)\b",
     allow=True, flags=re.I)

if os.path.isfile(terms_file):
    terms = [t.strip() for t in open(terms_file, encoding="utf-8") if t.strip() and not t.startswith("#")]
    if terms:
        scan("private terms (from %s)" % terms_file,
             "|".join(re.escape(t) for t in terms), flags=re.I)
    else:
        print("ok   private terms file %s is empty; nothing to check" % terms_file)
else:
    print("ok   private terms check skipped: %s not found (it only runs locally, never in CI)" % terms_file)
PY
)"
leak_rc=$?
while IFS= read -r line; do
  case "$line" in
    "ok   "*) echo "$line" ;;
    "FAIL "*) fail "${line#FAIL }" ;;
    *) fail "leak check: $line" ;;
  esac
done <<< "$leak_out"
[ "$leak_rc" -eq 0 ] || fail "leak check script exited with $leak_rc"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all skills checks passed"
