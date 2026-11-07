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
#      A line that warns against the pattern (never, do not, avoid, ...) is allowed.
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

def scan(label, pattern, keep=lambda m: True, flags=0):
    hits = []
    for rel, text in files:
        for n, line in enumerate(text.splitlines(), 1):
            for m in re.finditer(pattern, line, flags):
                if keep(m):
                    hits.append("%s:%d: %s" % (rel, n, m.group(0)))
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
# A line that clearly warns against the pattern is allowed: it has a warning
# word (never, do not, don.t, must not, avoid, forbidden) outside the match.
WARNING = re.compile(r"\b(never|do not|don.t|must not|mustn.t|avoid|forbidden|instead of)\b", re.I)
def warns(m):
    line = m.string
    return bool(WARNING.search(line[:m.start()] + " " + line[m.end():]))
danger = lambda m: not warns(m)
scan("pipe-to-shell instructions",
     r"\b(curl|wget)\b[^|\n]*\|\s*(sudo\s+)?(ba|z|da|k)?sh\b", keep=danger)
scan("rm -rf on a variable or /",
     r"\brm\s+(-[A-Za-z]*[rR][A-Za-z]*\s+|-[A-Za-z]+\s+-[rR]\s+)+(\"?\$\{?\w|/(?=[\s*\"]|$))",
     keep=danger)
scan("guard bypasses",
     r"--no-verify|dangerouslyDisableSandbox|--dangerously-skip-permissions"
     r"|\b(edit|modify|overwrite|delete|remove|disable|rm)\b[^\n]{0,30}\.claude/settings"
     r"|(?<![\w>])>>?\s*\S*\.claude/settings"
     r"|\b(remove|delete|disable|bypass|turn off|skip)\s+(the\s+)?([\w-]+\s+)?hooks?\b",
     keep=danger, flags=re.I)
scan("force pushes to a default branch",
     r"\bgit\s+push\b(?=[^\n]*(--force\b|--force-with-lease|\s-f\b|\s\+(main|master)\b))"
     r"(?=[^\n]*\b(main|master)\b)[^\n]*", keep=danger)
scan("base64-decoded execution",
     r"base64\s+(-d|-D|--decode)\b[^\n]*\|\s*(sudo\s+)?(ba|z)?sh\b|\beval\b[^\n]*base64"
     r"|base64\s+(-d|-D|--decode)\b[^\n]*\|\s*(python3?|perl|node|ruby)\b", keep=danger)
scan("prompt-injection phrases",
     r"\b(ignore|disregard|forget)\s+(all\s+|any\s+)?(the\s+)?(previous|prior|above|earlier|your)\s+"
     r"(instructions|rules|prompts?|guidelines)\b"
     r"|\byou are now (in )?(developer mode|DAN|jailbroken)\b"
     r"|\b(do not|don.t) (tell|inform|notify) the (user|owner)\b"
     r"|\bwithout (telling|asking|informing) the (user|owner)\b",
     keep=danger, flags=re.I)

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
