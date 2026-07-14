#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-issue.sh [--repo <owner/repo>] --title <title> --body-file <path> [--label <name> ...]
EOF
}

die() {
  printf 'create-issue: %s\n\n' "$1" >&2
  usage >&2
  exit 1
}

contains() {
  local needle=$1 value
  shift
  for value in "$@"; do
    [[ $needle != "$value" ]] || return 0
  done
  return 1
}

title=
body_file=
repository=
labels=()

while (($# > 0)); do
  case $1 in
    --help)
      usage
      exit 0
      ;;
    --title | --body-file | --label | --repo)
      (($# >= 2)) || die "Missing value for $1"
      option=$1
      value=$2
      [[ $value != --* ]] || die "Missing value for $option"
      case $option in
        --title) title=$value ;;
        --body-file) body_file=$value ;;
        --label) labels+=("$value") ;;
        --repo) repository=$value ;;
      esac
      shift 2
      ;;
    --)
      shift
      ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n ${title//[[:space:]]/} ]] || die "--title is required"
[[ -n $body_file ]] || die "--body-file is required"
[[ -f $body_file ]] || die "Body file does not exist: $body_file"
if [[ -n $repository && ! $repository =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
  die "--repo must use the owner/repo format"
fi

if [[ -n $repository ]]; then
  base="repos/$repository"
else
  base='repos/{owner}/{repo}'
fi
create_args=("$base/issues" -X POST -f "title=$title" -F "body=@$body_file")
for label in "${labels[@]}"; do
  create_args+=(-f "labels[]=$label")
done

if ! response=$(gh api "${create_args[@]}" --jq '.number, .html_url, (.labels[].name // empty)'); then
  exit 1
fi
mapfile -t issue_fields <<<"$response"
((${#issue_fields[@]} >= 2)) || die "GitHub returned an invalid issue response"
issue_number=${issue_fields[0]}
issue_url=${issue_fields[1]}
applied_labels=("${issue_fields[@]:2}")

missing_labels=()
for requested in "${labels[@]}"; do
  contains "$requested" "${applied_labels[@]}" || missing_labels+=("$requested")
done

if ((${#missing_labels[@]} > 0)); then
  repair_args=("$base/issues/$issue_number/labels" -X POST)
  for label in "${missing_labels[@]}"; do
    repair_args+=(-f "labels[]=$label")
  done
  if ! gh api "${repair_args[@]}" --silent; then
    printf 'create-issue: Issue created at %s, but label repair failed\n' "$issue_url" >&2
    exit 1
  fi

  if ! response=$(gh api "$base/issues/$issue_number" -X GET --jq '.labels[].name'); then
    printf 'create-issue: Issue created at %s, but label verification failed\n' "$issue_url" >&2
    exit 1
  fi
  mapfile -t applied_labels <<<"$response"

  for requested in "${labels[@]}"; do
    if ! contains "$requested" "${applied_labels[@]}"; then
      printf 'create-issue: Issue created at %s, but GitHub did not apply label: %s\n' \
        "$issue_url" "$requested" >&2
      exit 1
    fi
  done
fi

printf '%s\n' "$issue_url"
