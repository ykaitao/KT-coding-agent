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
cp "$tmp/ga.json" "$tmp/q.json"
printf '%s\n' '{"query": "\u006dutation { addPullRequestReview(input:{pullRequestId:\"X\", event:APPROVE}) { clientMutationId } }"}' > "$tmp/esc.json"
printf 'mutation { addPullRequestReview(input:{pullRequestId:"X", body:"event:COMMENT", event#x\n:APPROVE}) { clientMutationId } }\n' > "$tmp/decoy.graphql"

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
# GraphQL is denied outright, in every endpoint form and whatever the payload.
M='mutation { addPullRequestReview(input:{pullRequestId:"X", event:APPROVE}) { clientMutationId } }'
check 2 "gh api /graphql -f query='$M'"
check 2 "gh api https://api.github.com/graphql -f query='$M'"
check 2 "gh api HTTPS://API.GITHUB.COM/GraphQL -f query='$M'"
check 2 "/usr/local/bin/gh api graphql -f query='$M'"
check 2 'gh api graphql --input esc.json'
check 2 'gh api graphql -F query=@decoy.graphql'
check 2 'gh api graphql -f query=mutation{addPullRequestReview(input:{pullRequestId:"X",event:APPROVE}){clientMutationId}}'
check 2 'gh api graphql -f query="mutation { submitPullRequestReview(input:{pullRequestReviewId:\"X\", event: REQUEST_CHANGES}) { clientMutationId } }"'
check 2 'gh api graphql -F query=@qa.graphql'
check 2 'gh api graphql --input ga.json'
check 2 'gh api graphql -F query=@missing.graphql'
check 2 'gh api graphql -f query="mutation { addPullRequestReview(input:{pullRequestId:\"X\", event:COMMENT}) { clientMutationId } }"'
check 2 'gh api graphql -F query=@qr.graphql'
check 2 'gh api graphql --input gr.json'
check 2 'gh api graphql -f query="query { viewer { login } }"'
check 2 'gh api -X GET graphql'
grep -q 'u006d' "$tmp/esc.json" || { echo "FAIL esc.json lost its \\u escape"; fail=1; }
# Quote and backslash splitting: the shell still sees reviews and graphql.
check 2 "gh api repos/o/r/pulls/1/rev''iews -X POST -f event=APPROVE"
check 2 'gh api repos/o/r/pulls/1/rev""iews/9/events -X POST -f event=APPROVE'
check 2 "gh pr rev''iew 1 --approve"
check 2 "gh api gr''aphql --input q.json"
check 2 'gh api graph\ql --input q.json'
# gh aliases and shell expansion can hide api and graphql, so they're blocked.
check 2 'gh alias set g api'
check 2 'gh g graphql --input q.json'
check 2 "gh alias set gq 'api graphql'"
check 2 'gh gq --input q.json'
check 2 'gh api "$(printf gr)aphql" --input q.json'
check 2 'e=graph; gh api ${e}ql --input q.json'
check 2 'gh api repos/o/r/pulls/$N/comments'
check 2 'gh api repos/o/r/pulls/`echo 1`/comments'
check 2 'env gh alias set g api'
check 2 "bash -c 'gh alias set g api'"
check 2 'gh pr merge 1'
check 2 'gh repo delete o/r'
check 2 'gh extension install x/y'
# Allowed: the gh commands the skills and docs tell agents to run.
check 0 'gh api --paginate repos/o/r/pulls/1/comments --jq '"'"'.[] | {id, line, path, body, in_reply_to_id}'"'"
check 0 'gh api repos/o/r/pulls/1/comments/9/replies -f body=Fixed'
check 0 'gh api "repos/o/r/contents/README.md?ref=abc123" --jq .content | base64 -d | sed -n '"'"'5p'"'"
check 0 'gh api repos/o/r/pulls/1/reviews -X POST --input c.json'
check 0 'gh auth status'
check 0 'gh pr checkout 1'
check 0 'gh pr checks 1 --repo o/r --watch'
check 0 'gh pr diff 1 --repo o/r'
check 0 'gh pr update-branch 1 --repo o/r'
check 0 'gh pr view 1 --repo o/r --json headRefOid -q .headRefOid'
check 0 'gh pr review 1 --comment -b ok'
check 0 'gh issue comment 10 --repo o/r --body-file note.md'
check 0 'gh pr create --repo o/r --base master --head x --title t --body-file b.md'
check 0 'git log --oneline -1 && gh pr checks 1 --repo o/r'
check 0 'git commit -m "mention gh alias in a message"'
# Mentioning graphql outside gh api is fine.
check 0 'grep -rn graphql docs'

exit $fail
