#!/bin/bash

# This script lists files in the current directory whose name prefixes are duplicated.
#
# Usage:
#   list-prefix-duplicate-files.sh [prefix_length]
#
# Example:
#   list-prefix-duplicate-files.sh 4

set -euo pipefail

PREFIX_LEN="${1:-6}"

# Validate argument
if ! [[ "$PREFIX_LEN" =~ ^[0-9]+$ ]] || [[ "$PREFIX_LEN" -le 0 ]]; then
  echo "Error: prefix length must be a positive integer" >&2
  exit 1
fi

# List files and group by prefix
printf "%s\n" * | awk -v n="$PREFIX_LEN" '
{
  prefix = substr($0, 1, n)
  count[prefix]++
  files[prefix] = files[prefix] "\n" $0
}
END {
  for (p in count) {
    if (count[p] > 1) {
      sub(/^\n/, "", files[p])
      print files[p] "\n"
    }
  }
}
'
