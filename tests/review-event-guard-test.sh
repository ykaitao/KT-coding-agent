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
echo 'mutation { addPullRequestReview(input:{pullRequestId:"X", event:APPROVE}) { clientMutationId } }' > "$tmp/qa.graphql"
echo 'mutation { addPullRequestReview(input:{pullRequestId:"X", event:COMMENT}) { clientMutationId } }' > "$tmp/qc.graphql"
echo 'query { repository(owner:"o", name:"r") { pullRequest(number:1) { reviews(first:5) { nodes { state } } } } }' > "$tmp/qr.graphql"
echo '{"query":"mutation($e: PullRequestReviewEvent!) { submitPullRequestReview(input:{pullRequestReviewId:\"X\", event:$e}) { clientMutationId } }","variables":{"e":"APPROVE"}}' > "$tmp/ga.json"
echo '{"query":"query { viewer { login } }"}' > "$tmp/gr.json"

fail=0
check() { # expected_exit command
  local expected=$1 cmd=$2 got
  printf '{"cwd":%s,"tool_input":{"command":%s}}' \
    "$(jq -Rn --arg v "$tmp" '$v')" "$(jq -Rn --arg v "$cmd" '$v')" \
    | python3 -I "$hook" 2>/dev/null
  got=$?
  if [ "$got" -eq "$expected" ]; then echo "ok   $got  $cmd"; else echo "FAIL $got (want $expected)  $cmd"; fail=1; fi
}
check_raw() { # expected_exit raw_stdin: malformed hook input must still block
  local expected=$1 input=$2 got
  printf '%s' "$input" | python3 -I "$hook" 2>/dev/null
  got=$?
  if [ "$got" -eq "$expected" ]; then echo "ok   $got  input: $input"; else echo "FAIL $got (want $expected)  input: $input"; fail=1; fi
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
# Blocked: malformed hook input fails closed (exit 2), never exit 1.
check_raw 2 'not json'
check_raw 2 '{"tool_input":"x"}'
check_raw 2 '{"tool_input":{}}'
check_raw 2 '{"tool_input":{"command":5}}'
# GraphQL: review mutations need event COMMENT; queries and other mutations pass.
check 2 'gh api graphql -f query=mutation{addPullRequestReview(input:{pullRequestId:"X",event:APPROVE}){clientMutationId}}'
check 2 'gh api graphql -f query="mutation { submitPullRequestReview(input:{pullRequestReviewId:\"X\", event: REQUEST_CHANGES}) { clientMutationId } }"'
check 2 'gh api graphql -f query="mutation { updatePullRequestReview(input:{pullRequestReviewId:\"X\", body:\"x\"}) { clientMutationId } }"'
check 2 'gh api graphql -f query="mutation(\$e: PullRequestReviewEvent!) { submitPullRequestReview(input:{pullRequestReviewId:\"X\", event:\$e}) { clientMutationId } }" -f e=APPROVE'
check 2 'gh api graphql -F query=@qa.graphql'
check 2 'gh api graphql --input ga.json'
check 2 'gh api graphql -F query=@missing.graphql'
check 2 'gh api graphql --input missing.json'
check 2 'cp qa.graphql qc.graphql ; gh api graphql -F query=@qc.graphql'
check 0 'gh api graphql -f query="mutation { addPullRequestReview(input:{pullRequestId:\"X\", event:COMMENT}) { clientMutationId } }"'
check 0 'gh api graphql -F query=@qc.graphql'
check 0 'gh api graphql -F query=@qr.graphql'
check 0 'gh api graphql --input gr.json'
check 0 'gh api graphql -f query="query { viewer { login } }"'
check 0 'gh api graphql -f query="mutation { addPullRequestReviewComment(input:{pullRequestReviewId:\"X\", body:\"x\"}) { clientMutationId } }"'

exit $fail
