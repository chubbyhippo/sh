#!/usr/bin/env sh

line_exists() {
  if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: line_exists "TEXT" FILE' >&2
    return 2
  fi

  [ -f "$2" ] && grep -F -x -q -e "$1" "$2"
}

if [ "$#" -ne 2 ]; then
  printf '%s\n' 'Usage: append "TEXT" FILE' >&2
  exit 2
fi

line=$1
file=$2
# Do nothing if the exact line already exists
if line_exists "$line" "$file"; then
  exit 0
fi

printf '%s\n' "$line" >> "$file"