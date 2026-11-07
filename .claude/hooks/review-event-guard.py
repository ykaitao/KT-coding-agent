#!/usr/bin/env python3
# PreToolUse hook: allow PR reviews only with event COMMENT. Fails closed.
#
# Known limits: this is a guardrail against mistakes and casual workarounds, not a
# sandbox. Human approval of merges and human code review remain the real control.
# It reads one command line before it runs, so it can't see:
# - scripts written to a file in one command and run in another (a script, a sourced
#   file, a Makefile target);
# - interpreters that run gh themselves (python3 -c "os.system('gh pr merge 1')",
#   node -e, awk 'BEGIN{system("gh ...")}', perl -e);
# - indirection through environment variables or files it doesn't read (for example
#   GH_* settings, or a git alias in a config file it isn't pointed at);
# - a gh alias set before the hook was installed, a gh binary whose name is built by
#   shell expansion, a wrapper not in RUNNERS, and API calls made without gh (curl).
import json, os, re, shlex, subprocess, sys

def block(why):
    print(f"Blocked: {why}. PR reviews may only be posted with event COMMENT.", file=sys.stderr)
    sys.exit(2)

# gh subcommands agents may run. Anything else, including gh alias and unknown
# aliases, is blocked, because an alias can hide an api or graphql call.
GH_ALLOWED = {
    "api": None,
    "auth": {"status"},
    "issue": {"view", "list", "create", "comment"},
    "pr": {"view", "diff", "checks", "list", "create", "review", "update-branch", "checkout", "comment", "edit"},
    "repo": {"view"},
    "run": {"view", "list"},
}

def split_segments(cmd):
    """Split a command line into simple commands at ; & | && || ( ) and newlines."""
    lex = shlex.shlex(cmd.replace("\n", " ; "), posix=True, punctuation_chars=";&|()")
    lex.whitespace_split = True
    segments, cur = [], []
    for tok in lex:
        if tok and set(tok) <= set(";&|()"):
            if cur:
                segments.append(cur)
            cur = []
        else:
            cur.append(tok)
    if cur:
        segments.append(cur)
    return segments

def check_gh(seg, cmd):
    """Allowlist gh subcommands, and block shell expansion and GraphQL in gh calls."""
    starts = [i for i, t in enumerate(seg) if os.path.basename(t) == "gh"]
    if not starts:
        return
    # A gh call whose arguments come from shell expansion can't be known before it
    # runs. Single-quoted text (such as a jq filter) isn't expanded, so it's ignored.
    if re.search(r"\$[({A-Za-z_0-9]|`", re.sub(r"'[^']*'", "", cmd)):
        block("shell expansion in a gh command; write its arguments out literally")
    merge = False
    for i in starts:
        args = seg[i + 1:]
        words = [a for a in args if not a.startswith("-")]
        sub = words[0] if words else ""
        if sub == "pr" and len(words) > 1 and words[1] == "merge":
            merge = True  # the caller turns a plain merge into an "ask"
            continue
        if sub not in GH_ALLOWED:
            block(f"gh {sub or args[:1]} is not allowed for agents")
        allowed = GH_ALLOWED[sub]
        if allowed is not None and (len(words) < 2 or words[1] not in allowed):
            block(f"gh {sub} {words[1] if len(words) > 1 else ''} is not allowed for agents".replace("  ", " "))
        if any("graphql" in a.lower() for a in args):
            block("GraphQL is not allowed for agents; use the REST endpoints")
        if sub == "pr" and words[1] == "review":
            flags = set(args)
            if not ({"--comment", "-c"} & flags) or {"--approve", "-a", "--request-changes", "-r"} & flags:
                block("gh pr review without --comment")
    return merge

RUNNERS = {"sh", "bash", "zsh", "dash", "ksh", "eval", "source", ".", "env", "nohup", "time",
           "command", "builtin", "xargs", "sudo", "doas", "exec", "nice", "timeout", "stdbuf",
           "watch", "parallel", "script", "ssh"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "eval", "source", "."}

def has_gh(s):
    """A gh word, after removing the quotes and backslashes a shell would remove."""
    return re.search(r"(?<![A-Za-z0-9_.-])gh(?![A-Za-z0-9_.-])", re.sub(r"[\"'\\]", "", s))

# git runs an alias that starts with ! as a shell command, and some settings
# (core.pager, core.editor, core.sshCommand...) run commands too. So block any
# git -c alias.*, any -c or git config value that mentions gh, any git config that
# writes an alias, and running an alias whose definition starts with !.
GIT_CONFIG_READS = {"--get", "--get-all", "--get-regexp", "--list", "-l", "--show-origin", "--name-only"}

def check_git(seg, cwd):
    for i, t in enumerate(seg):
        if os.path.basename(t) != "git":
            continue
        args, cvals, cdir, j = seg[i + 1:], [], None, 0
        while j < len(args) and args[j].startswith("-"):
            if args[j] in ("-c", "-C") and j + 1 < len(args):
                (cvals.append if args[j] == "-c" else (lambda v: None))(args[j + 1])
                if args[j] == "-C":
                    cdir = args[j + 1]
                j += 2
            else:
                j += 1
        for v in cvals:
            if v.lower().startswith("alias.") or has_gh(v):
                block("git -c with an alias or a gh command; run gh as its own command")
        if j >= len(args):
            continue
        sub, rest = args[j], args[j + 1:]
        if sub == "config":
            if not GIT_CONFIG_READS & set(rest) and any(
                    t.lower().startswith("alias.") or has_gh(t) for t in rest):
                block("git config that writes an alias or a gh command")
            continue
        base = cwd if os.path.isdir(cwd) else None
        if cdir:
            base = os.path.join(base or ".", cdir)
        try:
            out = subprocess.run(["git", "config", "--get", "alias." + sub], cwd=base,
                                 capture_output=True, text=True, timeout=5).stdout
        except Exception:
            block("could not check whether a git command is a shell alias")
        if out.strip().startswith("!"):
            block(f"git {sub} is a shell alias (!...), which can run anything")

def main():
    data = json.load(sys.stdin)
    if not isinstance(data, dict) or not isinstance(data.get("tool_input"), dict):
        block("hook input is not the expected JSON object")
    cmd = data["tool_input"].get("command")
    if not isinstance(cmd, str):
        block("hook input has no command string")
    cwd = data.get("cwd", ".")

    # git aliases and command settings can run gh without the word gh in the command.
    if re.search(r"(?<![A-Za-z0-9_.-])git(?![A-Za-z0-9_.-])", cmd):
        try:
            git_segments = split_segments(cmd)
        except ValueError:
            git_segments = []
        for seg in git_segments:
            check_git(seg, cwd)

    # Quotes and backslashes don't change what the shell runs (rev''iews is reviews),
    # so the fast path looks at the command without them.
    if not re.search(r"review|graphql|\bgh\b", re.sub(r"[\"'\\]", "", cmd), re.I):
        sys.exit(0)
    try:
        raw = shlex.split(cmd)
        segments = split_segments(cmd)
    except ValueError:
        block("could not parse the command")
    # Fail closed on hidden gh calls. A gh word inside an argument is blocked only
    # where that argument can run as a command: when the simple command contains a
    # shell, eval or wrapper word (sh -c, env, nohup, xargs, find -exec sh, watch...),
    # or when the command line feeds a shell (pipe or here-doc into bash). Quotes and
    # backslashes are removed first, because an inner shell would remove them too.
    # A gh word in an ordinary argument, such as a commit message, is allowed.
    for seg in segments:
        if any(os.path.basename(t) in RUNNERS for t in seg) and any(has_gh(t) for t in seg):
            block("gh behind a shell, eval or wrapper; run gh as its own command")
        if seg and os.path.basename(seg[0]) in SHELLS and has_gh(cmd):
            block("a command line that feeds a shell must not contain gh")

    merge = False
    for seg in segments:
        merge = check_gh(seg, cmd) or merge

    # Merging is the owner's decision: a plain `gh pr merge` asks the user instead of
    # being blocked. Chained, redirected or wrapped merges are still blocked.
    if merge:
        if len(segments) != 1 or re.search(r"\|\||[;&|<>`\n]|\$\(", cmd) or os.path.basename(segments[0][0]) != "gh":
            block("gh pr merge must be run on its own, not chained or wrapped")
        if any("graphql" in t.lower() for t in segments[0]):
            block("GraphQL is not allowed for agents; use the REST endpoints")
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "Merging needs the owner's approval",
        }}))
        sys.exit(0)

    # Normalize --flag=value and -fVALUE / -FVALUE / -XVALUE into flag, value.
    tokens = []
    for t in raw:
        if t.startswith("--") and "=" in t:
            tokens += t.split("=", 1)
        elif re.match(r"-[fFX].", t):
            tokens += [t[:2], t[2:]]
        else:
            tokens.append(t)

    if not any(re.search(r"pulls/.*reviews", t, re.I) for t in tokens):
        sys.exit(0)

    # A plain read uses only these flags; anything else counts as a write.
    READ_FLAGS = {"--paginate", "--jq", "-q", "--template", "-t", "--silent", "--include", "-i", "--verbose", "--cache"}
    VALUE_FLAGS = {"--jq", "-q", "--template", "-t", "--cache"}
    writes, skip = False, False
    for t in tokens:
        if skip:
            skip = False
            continue
        if t.startswith("-") and t not in READ_FLAGS:
            writes = True
        skip = t in VALUE_FLAGS
    if not writes:
        sys.exit(0)

    # The hook runs before the command, so a chained command could rewrite the
    # --input file after this check. Review writes must stand alone.
    if re.search(r"\|\||[;&|<>`\n]|\$\(", cmd):
        block("post the review as a standalone command")

    def read_json_event(path):
        try:
            return json.load(open(os.path.join(cwd, path))).get("event")
        except Exception:
            return None  # stdin, unexpanded $VAR or ~, or unreadable file

    events = []
    for i, t in enumerate(tokens):
        nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
        if t in ("-f", "-F", "--field", "--raw-field") and nxt.startswith("event="):
            val = nxt[len("event="):]
            if t in ("-F", "--field") and val.startswith("@"):
                try:
                    val = open(os.path.join(cwd, val[1:])).read().strip()
                except Exception:
                    val = None
            events.append(val)
        if t == "--input":
            events.append(read_json_event(nxt))

    if not events:
        block("no event found in a review write")
    if any(e != "COMMENT" for e in events):
        block(f"event {events}")


# Fail closed: any unexpected error blocks (exit 2) instead of exiting 1, which
# Claude Code treats as a non-blocking error and lets the command run.
try:
    main()
except SystemExit:
    raise
except BaseException as e:
    block(f"the guard failed ({type(e).__name__}: {e})")
