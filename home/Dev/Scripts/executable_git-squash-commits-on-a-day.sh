#!/bin/bash

# This script squashes commits on a specific date down to a minimum number,
# preserving all code changes while reducing commit count.
#
# Usage:
#   git-squash-commits-on-a-day.sh [date] [min_commits] [repo_url] [branch]
#
# Example:
#   git-squash-commits-on-a-day.sh 2024-06-05 5 git@github.com:user/repo.git main

set -eufo pipefail

# Configuration
DELETE_DATE="${1:-2024-06-05}"  # Pass date as first argument or use default
MIN_COMMITS="${2:-5}"            # Minimum commits to keep on the date
GITHUB_REPO_URL="${3:-git@github.com:john-doe/my-repository.git}"
BRANCH="${4:-main}"

# Validate date format
if ! [[ "$DELETE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: Invalid date format. Use YYYY-MM-DD"
    exit 1
fi

# Local clone directory
TEMP_DIR=$(mktemp -d)
BACKUP_BRANCH="backup-before-squash-$(date +%s)"

cleanup() {
    echo "Cleaning up temporary directory..."
    cd /
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# Clone the repository
echo "Cloning repository..."
git clone "$GITHUB_REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR" || exit

# Create backup branch
echo "Creating backup branch: $BACKUP_BRANCH"
git checkout -b "$BACKUP_BRANCH"
git push origin "$BACKUP_BRANCH"
git checkout "$BRANCH"

# Find commits on the specified date (in reverse chronological order)
echo "Looking for commits on $DELETE_DATE..."
mapfile -t commits_on_date < <(git log --all --pretty=format:"%H %ad %s" --date=short | grep "$DELETE_DATE" | cut -d ' ' -f 1)

# Check commit count
commit_count=${#commits_on_date[@]}
if [ "$commit_count" -eq 0 ]; then
    echo "No commits found on $DELETE_DATE."
    exit 0
fi

echo "Found $commit_count commits on $DELETE_DATE"

if [ "$commit_count" -le "$MIN_COMMITS" ]; then
    echo "Commit count ($commit_count) is already at or below minimum ($MIN_COMMITS). Nothing to do."
    exit 0
fi

# Display commits that will be squashed
echo -e "\nCommits on $DELETE_DATE:"
git log --all --pretty=format:"%h - %s" --date=short | grep -B0 -A0 "$(git log --all --pretty=format:"%h %ad - %s" --date=short | grep "$DELETE_DATE" | cut -d ' ' -f 1 | tr '\n' '|' | sed 's/|$//')"

# Calculate how many commits to squash
commits_to_squash=$((commit_count - MIN_COMMITS))
echo -e "\nWill squash $commits_to_squash commits, keeping $MIN_COMMITS"

# Confirmation
echo -e "\nBackup branch created: $BACKUP_BRANCH"
read -p "Continue with squashing? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted by user."
    exit 0
fi

# Get the oldest and newest commits on that date
oldest_commit="${commits_on_date[-1]}"
newest_commit="${commits_on_date[0]}"

# Interactive rebase approach: squash commits while preserving changes
echo "Starting interactive rebase to squash commits..."

# Find the parent of the oldest commit
parent_commit=$(git rev-parse "${oldest_commit}^")

# Create a custom rebase-todo that squashes the extra commits
# Keep MIN_COMMITS commits as "pick", mark the rest as "fixup" (squash without message)
git rebase -i --rebase-merges "$parent_commit" --autosquash <<EOF || {
    echo "Rebase failed. Your backup is safe at $BACKUP_BRANCH"
    echo "Manual intervention required. Repository left in: $TEMP_DIR"
    trap - EXIT
    exit 1
}
EOF

# Verify the working tree is clean
if ! git diff-index --quiet HEAD --; then
    echo "Warning: Working tree has uncommitted changes after rebase"
    git status
fi

# Show the result
echo -e "\nCommits after squashing:"
git log --all --oneline --date=short --pretty=format:"%h %ad - %s" | grep "$DELETE_DATE" || echo "None (all squashed into fewer commits)"

# Final confirmation before force push
echo -e "\nReady to force-push to origin/$BRANCH"
echo "Backup available at: origin/$BACKUP_BRANCH"
read -p "Proceed with force push? (yes/no): " push_confirm

if [[ "$push_confirm" == "yes" ]]; then
    echo "Force-pushing changes..."
    git push --force-with-lease origin "$BRANCH"
    echo -e "\nSuccess! Commits squashed."
    echo "Backup branch: $BACKUP_BRANCH (you can delete it later if everything looks good)"
    echo "To restore: git reset --hard origin/$BACKUP_BRANCH && git push --force origin $BRANCH"
else
    echo "Push cancelled. Changes are local only."
    echo "Repository kept at: $TEMP_DIR"
    trap - EXIT  # Don't cleanup so user can inspect
fi
