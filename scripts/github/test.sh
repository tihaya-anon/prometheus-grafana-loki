#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/state"

cat >"$test_root/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

count_file=$MOCK_STATE_DIR/count
count=0
[[ ! -f $count_file ]] || count=$(<"$count_file")
count=$((count + 1))
printf '%s' "$count" >"$count_file"
printf '%s\n' "$@" >"$MOCK_STATE_DIR/call.$count"

emit_label() {
  local value
  for value in "$@"; do
    printf 'b64:%s\n' "$(printf '%s' "$value" | base64 --wrap=0)"
  done
}

case "$MOCK_SCENARIO:$count" in
  create-repair:1) printf '42\nhttps://github.com/example/project/issues/42\n' ;;
  create-repair:2) ;;
  create-repair:3) printf 'ready-for-agent\n' ;;
  create-explicit:1) printf '7\nhttps://github.com/example/platform/issues/7\nready-for-agent\n' ;;
  create-unlabeled:1) printf '8\nhttps://github.com/example/project/issues/8\n' ;;
  create-repair-fails:1) printf '42\nhttps://github.com/example/project/issues/42\n' ;;
  create-repair-fails:2)
    printf 'permission denied\n' >&2
    exit 1
    ;;
  ensure-missing:1)
    printf 'gh: Not Found (HTTP 404)\n' >&2
    exit 1
    ;;
  ensure-missing:2 | ensure-update:2 | ensure-explicit:1)
    emit_label ready-for-agent 0E8A16 'Fully specified and ready for an agent'
    ;;
  ensure-empty:1) emit_label 'needs info' 0E8A16 '' ;;
  ensure-escaped:1) emit_label 'needs-info' 0E8A16 $'Line one\tC:\\logs\n' ;;
  ensure-update:1) emit_label ready-for-agent ffffff Stale ;;
  *)
    printf 'Unexpected mock call: %s:%s\n' "$MOCK_SCENARIO" "$count" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$test_root/bin/gh"

export PATH="$test_root/bin:$PATH"
export MOCK_STATE_DIR="$test_root/state"
body_file="$test_root/issue.md"
printf 'Issue body\n' >"$body_file"

reset_scenario() {
  rm -f "$MOCK_STATE_DIR"/*
  export MOCK_SCENARIO=$1
}

assert_eq() {
  local expected=$1 actual=$2
  if [[ $actual != "$expected" ]]; then
    printf 'Expected <%s>, got <%s>\n' "$expected" "$actual" >&2
    exit 1
  fi
}

assert_call_contains() {
  local call=$1 expected=$2
  grep -Fxq -- "$expected" "$MOCK_STATE_DIR/call.$call" || {
    printf 'Call %s did not contain <%s>\n' "$call" "$expected" >&2
    exit 1
  }
}

reset_scenario create-repair
output=$("$(dirname "$0")/create-issue.sh" \
  --title "Agent Run Diagnosis v1" --body-file "$body_file" --label ready-for-agent)
assert_eq "https://github.com/example/project/issues/42" "$output"
assert_call_contains 1 'repos/{owner}/{repo}/issues'
assert_call_contains 2 'labels[]=ready-for-agent'
assert_call_contains 3 'repos/{owner}/{repo}/issues/42'

reset_scenario create-repair-fails
if "$(dirname "$0")/create-issue.sh" \
  --title "Agent Run Diagnosis v1" --body-file "$body_file" --label ready-for-agent \
  >"$test_root/output" 2>"$test_root/error"; then
  printf 'Expected label repair failure\n' >&2
  exit 1
fi
grep -Fq 'Issue created at https://github.com/example/project/issues/42' "$test_root/error"

reset_scenario create-explicit
output=$("$(dirname "$0")/create-issue.sh" --repo example/platform \
  --title "Provision Tempo" --body-file "$body_file" --label ready-for-agent)
assert_eq "https://github.com/example/platform/issues/7" "$output"
assert_call_contains 1 'repos/example/platform/issues'

reset_scenario create-unlabeled
output=$("$(dirname "$0")/create-issue.sh" \
  --title "Unlabelled issue" --body-file "$body_file")
assert_eq "https://github.com/example/project/issues/8" "$output"
assert_eq 1 "$(<"$MOCK_STATE_DIR/count")"

reset_scenario ensure-missing
output=$("$(dirname "$0")/ensure-label.sh" --name ready-for-agent --color 0E8A16 \
  --description "Fully specified and ready for an agent")
assert_eq ready-for-agent "$output"
assert_call_contains 1 'repos/{owner}/{repo}/labels/ready-for-agent'
assert_call_contains 2 'repos/{owner}/{repo}/labels'

reset_scenario ensure-update
output=$("$(dirname "$0")/ensure-label.sh" --name ready-for-agent --color 0E8A16 \
  --description "Fully specified and ready for an agent")
assert_eq ready-for-agent "$output"
assert_call_contains 2 PATCH
assert_call_contains 2 'color=0E8A16'

reset_scenario ensure-explicit
output=$("$(dirname "$0")/ensure-label.sh" --repo example/platform \
  --name ready-for-agent --color 0E8A16 \
  --description "Fully specified and ready for an agent")
assert_eq ready-for-agent "$output"
assert_call_contains 1 'repos/example/platform/labels/ready-for-agent'

reset_scenario ensure-empty
output=$("$(dirname "$0")/ensure-label.sh" --name "needs info" --color 0E8A16)
assert_eq "needs info" "$output"
assert_call_contains 1 'repos/{owner}/{repo}/labels/needs%20info'

reset_scenario ensure-escaped
output=$("$(dirname "$0")/ensure-label.sh" --name needs-info --color 0E8A16 \
  --description $'Line one\tC:\\logs\n')
assert_eq needs-info "$output"
assert_eq 1 "$(<"$MOCK_STATE_DIR/count")"

printf 'GitHub script tests passed.\n'
