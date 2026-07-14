#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ensure-label.sh [--repo <owner/repo>] --name <name> --color <RRGGBB> [--description <text>]
EOF
}

die() {
  printf 'ensure-label: %s\n\n' "$1" >&2
  usage >&2
  exit 1
}

urlencode() {
  local value=$1 encoded= character hex index
  LC_ALL=C
  for ((index = 0; index < ${#value}; index += 1)); do
    character=${value:index:1}
    case $character in
      [a-zA-Z0-9.~_-]) encoded+=$character ;;
      *)
        printf -v hex '%%%02X' "'$character"
        encoded+=$hex
        ;;
    esac
  done
  printf '%s' "$encoded"
}

validate_response() {
  local response=$1
  local -a fields
  local response_name response_color response_description
  mapfile -t fields <<<"$response"
  ((${#fields[@]} == 3)) || return 1
  response_name=$(printf '%s' "${fields[0]#b64:}" | base64 --decode; printf x)
  response_color=$(printf '%s' "${fields[1]#b64:}" | base64 --decode; printf x)
  response_description=$(printf '%s' "${fields[2]#b64:}" | base64 --decode; printf x)
  response_name=${response_name%x}
  response_color=${response_color%x}
  response_description=${response_description%x}
  [[ $response_name == "$name" && ${response_color,,} == "${color,,}" && \
    $response_description == "$description" ]]
}

name=
color=
description=
repository=

while (($# > 0)); do
  case $1 in
    --help)
      usage
      exit 0
      ;;
    --name | --color | --description | --repo)
      (($# >= 2)) || die "Missing value for $1"
      option=$1
      value=$2
      [[ $value != --* ]] || die "Missing value for $option"
      case $option in
        --name) name=$value ;;
        --color) color=$value ;;
        --description) description=$value ;;
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

[[ -n ${name//[[:space:]]/} ]] || die "--name is required"
[[ $color =~ ^[0-9a-fA-F]{6}$ ]] || die "--color must be a six-digit hexadecimal value without #"
if [[ -n $repository && ! $repository =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
  die "--repo must use the owner/repo format"
fi

if [[ -n $repository ]]; then
  base="repos/$repository"
else
  base='repos/{owner}/{repo}'
fi
endpoint="$base/labels/$(urlencode "$name")"
error_file=$(mktemp)
trap 'rm -f "$error_file"' EXIT

response_filter='[.name, .color, (.description // "")] | map(@base64) | .[] | "b64:\(.)"'
if response=$(gh api "$endpoint" -X GET --jq "$response_filter" 2>"$error_file"); then
  if validate_response "$response"; then
    printf '%s\n' "$name"
    exit 0
  fi

  response=$(gh api "$endpoint" -X PATCH \
    -f "new_name=$name" -f "color=$color" -f "description=$description" \
    --jq "$response_filter")
else
  error=$(<"$error_file")
  if [[ $error != *"HTTP 404"* ]]; then
    printf '%s\n' "$error" >&2
    exit 1
  fi

  response=$(gh api "$base/labels" -X POST \
    -f "name=$name" -f "color=$color" -f "description=$description" \
    --jq "$response_filter")
fi

validate_response "$response" || die "GitHub did not apply the requested configuration for label: $name"
printf '%s\n' "$name"
