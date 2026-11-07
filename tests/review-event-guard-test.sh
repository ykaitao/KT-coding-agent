#!/usr/bin/env bash
# Tests for .claude/hooks/review-event-guard.py. Run from anywhere: bash tests/review-event-guard-test.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/.claude/hooks/review-event-guard.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo '{"event":"COMMENT"}' > "$tmp/c.json"
echo '{"event":"APPROVE"}' > "$tmp/a.json"
echo 'APPROVE' > "$tmp/ev.txt"
echo 'COMMENT' > "$tmp/evc.txt"

fail=0
check() { # expected_exit command
  local expected=$1 cmd=$2 got
  printf '{"cwd":%s,"tool_input":{"command":%s}}' \
    "$(jq -Rn --arg v "$tmp" '$v')" "$(jq -Rn --arg v "$cmd" '$v')" \
    | python3 -I "$hook" 2>/dev/null
  got=$?
  if [ "$got" -eq "$expected" ]; then echo "ok   $got  $cmd"; else echo "FAIL $got (want $expected)  $cmd"; fail=1; fi
}

R=repos/o/r/pulls/1/reviews
# Allowed: comment-only reviews and reads.
check 0 "gh api $R -X POST --input c.json"
check 0 "gh api $R --field=event=COMMENT"
check 0 "gh api $R -f event=COMMENT -f body=ok"
check 0 "gh api $R"
check 0 "gh api --paginate $R --jq .[0].id"
check 0 "gh pr review 1 --comment -b ok"
check 0 "gh api $R -F event=@evc.txt"
check 0 "git status"
# Blocked: approvals and request-changes in every flag form.
check 2 "gh api $R -X POST --input a.json"
check 2 "gh api -X POST $R --input a.json"
check 2 "gh api $R -XPOST --input=a.json"
check 2 "gh api $R -f event=APPROVE"
check 2 "gh api $R -fevent=APPROVE"
check 2 "gh api $R --raw-field=event=APPROVE"
check 2 "gh api $R -F event=REQUEST_CHANGES"
check 2 "gh api $R -F event=@ev.txt"
check 2 "gh api $R -F event=@missing.txt"
check 2 "gh api $R --method=PUT -f body=x"
check 2 "gh api $R -X POST -f body=no-event"
check 2 "gh pr review 1 --approve"
check 2 "gh pr review 1 --comment --approve"
check 2 "gh pr review 1 --request-changes -b x"
# Blocked: review writes combined with other commands (the file can change first).
check 2 "printf x > c.json && gh api $R -X POST --input c.json"
check 2 "cp a.json c.json & gh api $R -X POST --input c.json"
check 2 "gh api $R -X POST --input c.json ; echo hi"
check 2 "gh api $R -X POST --input c.json | cat"
check 2 "gh api $R -X POST --input c.json \$(cp a.json c.json)"
check 2 $'cp a.json c.json\ngh api '"$R"$' -X POST --input c.json'
check 2 "gh api $R -X POST --input c.json || true"
check 2 "gh api $R -X POST --input c.json \`true\`"
check 2 "gh api $R -X POST --input c.json < c.json"

exit $fail
