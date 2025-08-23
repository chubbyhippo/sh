#!/usr/bin/env sh

line_exists() {
  if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: line_exists "TEXT" FILE' >&2
    return 2
  fi

  [ -f "$2" ] && grep -F -x -e "$1" "$2" >/dev/null 2>&1
}

print_usage() {
  printf '%s\n' 'Usage:' >&2
  printf '%s\n' '  prepend.sh --line "TEXT" FILE' >&2
  printf '%s\n' '  prepend.sh "TEXT" FILE             (default mode is --line)' >&2
  printf '%s\n' '  prepend.sh --file SRC_FILE DST_FILE' >&2
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

  # Do nothing if the exact line already exists
  if line_exists "$line" "$file"; then
    exit 0
  fi

  tmp="${file}.$$.__tmp"
  if [ -f "$file" ]; then
    { printf '%s\n' "$line"; cat "$file"; } > "$tmp" || exit 1
  else
    printf '%s\n' "$line" > "$tmp" || exit 1
  fi
  mv "$tmp" "$file" || exit 1
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

  # Prepare temporary files alongside destination path
  tmp_head="${dst}.$$.__head"   # lines to prepend (unique, in src order)
  tmp_check="${dst}.$$.__chk"   # accumulator for duplicate checks
  tmp_new="${dst}.$$.__new"     # final new file

  # Initialize tmp_check with current dst content (or empty if missing)
  if [ -f "$dst" ]; then
    cat "$dst" > "$tmp_check" 2>/dev/null || : > "$tmp_check"
  else
    : > "$tmp_check"
  fi
  : > "$tmp_head"

  # Collect lines from src that are not already in dst (and avoid duplicates within src)
  while IFS= read -r l || [ -n "$l" ]; do
    if ! line_exists "$l" "$tmp_check"; then
      printf '%s\n' "$l" >> "$tmp_head" || { rm -f "$tmp_head" "$tmp_check"; exit 1; }
      printf '%s\n' "$l" >> "$tmp_check" || { rm -f "$tmp_head" "$tmp_check"; exit 1; }
    fi
  done < "$src"

  # Build new destination: head (unique src lines) + existing dst content (if any)
  if [ -f "$dst" ]; then
    cat "$tmp_head" "$dst" > "$tmp_new" || { rm -f "$tmp_head" "$tmp_check"; exit 1; }
  else
    cat "$tmp_head" > "$tmp_new" || { rm -f "$tmp_head" "$tmp_check"; exit 1; }
  fi

  mv "$tmp_new" "$dst" || { rm -f "$tmp_head" "$tmp_check" "$tmp_new"; exit 1; }
  rm -f "$tmp_head" "$tmp_check"
  exit 0
fi

print_usage
exit 2