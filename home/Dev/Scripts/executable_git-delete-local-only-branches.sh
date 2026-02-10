#!/bin/bash

# This script deletes local-only git branches that are not present on the remote repository.
#
# Usage:
#   git-delete-local-only-branches.sh
#
# Example:
#   git-delete-local-only-branches.sh

set -eufo pipefail

git fetch --prune

git branch --format "%(refname:short)" | while read branch; do
  if ! git show-ref --quiet refs/remotes/origin/$branch; then
    echo "Deleting localonly branch: $branch"
    git branch -d $branch
  fi
done