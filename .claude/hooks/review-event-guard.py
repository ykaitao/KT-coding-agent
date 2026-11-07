#!/usr/bin/env python3
# PreToolUse hook: allow PR reviews only with event COMMENT. Fails closed.
import json, os, re, shlex, sys

def block(why):
    print(f"Blocked: {why}. PR reviews may only be posted with event COMMENT.", file=sys.stderr)
    sys.exit(2)

def main():
    data = json.load(sys.stdin)
    if not isinstance(data, dict) or not isinstance(data.get("tool_input"), dict):
        block("hook input is not the expected JSON object")
    cmd = data["tool_input"].get("command")
    if not isinstance(cmd, str):
        block("hook input has no command string")
    cwd = data.get("cwd", ".")

    if not re.search(r"review|graphql", cmd, re.I):
        sys.exit(0)
    try:
        raw = shlex.split(cmd)
    except ValueError:
        block("could not parse the command")

    # Normalize --flag=value and -fVALUE / -FVALUE / -XVALUE into flag, value.
    tokens = []
    for t in raw:
        if t.startswith("--") and "=" in t:
            tokens += t.split("=", 1)
        elif re.match(r"-[fFX].", t):
            tokens += [t[:2], t[2:]]
        else:
            tokens.append(t)

    # GraphQL is denied outright: the loop only needs REST, and parsing GraphQL
    # documents for review events kept losing to encodings and comments.
    is_gh_api = "api" in tokens and any(os.path.basename(t) == "gh" for t in tokens)
    if is_gh_api and any("graphql" in t.lower() for t in tokens):
        block("GraphQL is not allowed for agents; use the REST endpoints")

    # gh pr review: only --comment / -c is allowed.
    if "gh" in tokens and "pr" in tokens and "review" in tokens:
        if not ({"--comment", "-c"} & set(tokens)) or {"--approve", "-a", "--request-changes", "-r"} & set(tokens):
            block("gh pr review without --comment")

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
