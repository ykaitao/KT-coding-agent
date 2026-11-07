#!/usr/bin/env bash
# Reports conflicts between this repo's skills and the user's own skills:
#   1. same name: which copy each provider loads
#   2. near-duplicate descriptions: word overlap (Jaccard) at or above a threshold
# Read-only. From each user skill it reads only the name and description in the
# SKILL.md frontmatter, and it prints only names, paths and scores.
# Usage: bash tests/skills-conflicts.sh [--strict] [--threshold N] [--repo-skills DIR] [--user-dirs DIR:DIR...]
# User dirs default to $KT_SKILLS_USER_DIRS, or else ~/.claude/skills, ~/.codex/skills,
# ~/.agents/skills and ~/.copilot/skills. Exits 0 with warnings; with --strict, exits 1
# if any skill name collides.
set -u

root="$(cd "$(dirname "$0")/.." && pwd -P)"
repo_skills="$root/skills"
user_dirs="${KT_SKILLS_USER_DIRS:-$HOME/.claude/skills:$HOME/.codex/skills:$HOME/.agents/skills:$HOME/.copilot/skills}"
strict=0
threshold=0.5
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) strict=1 ;;
    --threshold) threshold=${2:?--threshold needs a value}; shift ;;
    --repo-skills) repo_skills=${2:?--repo-skills needs a directory}; shift ;;
    --user-dirs) user_dirs=${2:?--user-dirs needs a colon-separated list}; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

python3 -I - "$repo_skills" "$user_dirs" "$strict" "$threshold" <<'PY'
import os, re, sys

repo_dir, user_dirs, strict, threshold = sys.argv[1], sys.argv[2], sys.argv[3] == "1", float(sys.argv[4])

# Which copy wins on a same-name collision, by the provider that reads the user folder.
# Source: the provider table in issue #32 (Claude Code skills docs, Codex skills docs;
# Copilot's rule isn't documented).
WINNER = {
    ".claude": "Claude Code loads the personal copy; it overrides the repo's",
    ".codex": "Codex shows both copies; it doesn't merge them",
    ".agents": "Codex shows both copies; Copilot's rule isn't documented",
    ".copilot": "Copilot's rule isn't documented",
}
STOP = set("a an and are as at be by for from in into is it its of on or the this that to use used when with you your".split())

def front(path):
    """Name and description from the SKILL.md frontmatter; stops at the closing ---."""
    name = desc = None
    with open(path, encoding="utf-8", errors="replace") as f:
        if f.readline().strip() != "---":
            return None, None
        key = None
        for n, line in enumerate(f):
            if line.strip() == "---" or n >= 40:
                break  # never read past the frontmatter
            if line[:1].isspace() and key == "description":
                desc = (desc or "") + " " + line.strip()
                continue
            key, _, value = line.partition(":")
            key, value = key.strip(), value.strip().strip("'\"")
            if key == "name":
                name = value
            elif key == "description":
                desc = "" if value in (">", "|", ">-", "|-") else value
    return name, desc

def skills(d):
    out = {}
    if not os.path.isdir(d):
        return out
    for entry in sorted(os.listdir(d)):
        path = os.path.join(d, entry, "SKILL.md")
        if os.path.isfile(path):
            name, desc = front(path)
            out[name or entry] = (os.path.join(d, entry), desc or "")
    return out

def words(text):
    return {w for w in re.findall(r"[a-z0-9]+", text.lower()) if len(w) > 2 and w not in STOP}

def provider(d):
    parent = os.path.basename(os.path.dirname(os.path.abspath(d)))
    return WINNER.get(parent, "unknown provider for this folder; check its docs")

repo = skills(repo_dir)
repo_real = os.path.realpath(repo_dir)
collisions = similar = 0
dirs = [d for d in user_dirs.split(":") if d]
for d in dirs:
    if os.path.realpath(d) == repo_real:
        continue
    for uname, (upath, udesc) in skills(d).items():
        if os.path.realpath(upath).startswith(repo_real + os.sep):
            continue  # a link back to this repo's own skill, not a second copy
        if uname in repo:
            collisions += 1
            print(f"WARN same name: {uname}: {upath} and {repo[uname][0]}. {provider(d)}.")
            continue
        uw = words(udesc)
        for rname, (rpath, rdesc) in repo.items():
            rw = words(rdesc)
            if uw and rw:
                score = len(uw & rw) / len(uw | rw)
                if score >= threshold:
                    similar += 1
                    print(f"WARN similar description ({score:.2f}): {uname} ({upath}) and {rname} ({rpath})")

print(f"skills conflicts: {len(repo)} repo skills, {len(dirs)} user folders, "
      f"{collisions} same-name, {similar} similar")
sys.exit(1 if strict and collisions else 0)
PY
