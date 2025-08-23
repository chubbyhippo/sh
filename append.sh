#!/usr/bin/env sh

line_exists() {
  if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: line_exists "TEXT" FILE' >&2
    return 2
  fi

  [ -f "$2" ] && grep -F -x -q -e "$1" "$2"
}

print_usage() {
  printf '%s\n' 'Usage:' >&2
  printf '%s\n' '  append.sh --line "TEXT" FILE' >&2
  printf '%s\n' '  append.sh "TEXT" FILE            (default mode is --line)' >&2
  printf '%s\n' '  append.sh --file SRC_FILE DST_FILE' >&2
}

# Parse flags anywhere (before/after positionals). Default mode is --line if unspecified.
mode=""
positional_set=""
after_dd=0

for arg in "$@"; do
  if [ "$after_dd" -eq 0 ] && [ "$arg" = "--" ]; then
    after_dd=1
    continue
  fi

  if [ "$after_dd" -eq 0 ] && [ "$arg" = "--line" ]; then
    if [ -n "$mode" ] && [ "$mode" != "line" ]; then
      printf '%s\n' 'Error: Conflicting modes specified.' >&2
      print_usage
      exit 2
    fi
    mode="line"
    continue
  fi

  if [ "$after_dd" -eq 0 ] && [ "$arg" = "--file" ]; then
    if [ -n "$mode" ] && [ "$mode" != "file" ]; then
      printf '%s\n' 'Error: Conflicting modes specified.' >&2
      print_usage
      exit 2
    fi
    mode="file"
    continue
  fi

  if [ "$after_dd" -eq 0 ] && [ "${arg#--}" != "$arg" ]; then
    printf 'Error: Unknown flag: %s\n' "$arg" >&2
    print_usage
    exit 2
  fi

  q=$(printf "%s" "$arg" | sed "s/'/'\\\\''/g; s/.*/'&'/")
  positional_set="$positional_set $q"
done

[ -z "$mode" ] && mode="line"

# Replace positional parameters with collected ones
# shellcheck disable=SC2086
eval "set -- $positional_set"

if [ "$mode" = "line" ]; then
  if [ "$#" -ne 2 ]; then
    print_usage
    exit 2
  fi
  line=$1
  file=$2

  if line_exists "$line" "$file"; then
    exit 0
  fi

  printf '%s\n' "$line" >> "$file"
  exit 0
fi

if [ "$mode" = "file" ]; then
  if [ "$#" -ne 2 ]; then
    print_usage
    exit 2
  fi
  src=$1
  dst=$2

  if [ ! -f "$src" ]; then
    printf '%s\n' "Source file not found: $src" >&2
    exit 1
  fi

  touch "$dst" 2>/dev/null || {
    printf '%s\n' "Cannot create or write to destination file: $dst" >&2
    exit 1
  }

  # Append each unique line from src to dst (exact, whole-line matches)
  while IFS= read -r l || [ -n "$l" ]; do
    if ! line_exists "$l" "$dst"; then
      printf '%s\n' "$l" >> "$dst"
    fi
  done < "$src"
  exit 0
fi

print_usage
exit 2