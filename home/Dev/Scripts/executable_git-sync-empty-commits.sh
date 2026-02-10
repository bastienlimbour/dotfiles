#!/bin/bash

# This script retroactively syncs commits from source repositories to a target repository
# by creating empty commits with matching dates and author information.
#
# Usage:
#   git-sync-empty-commits.sh
#
# Example:
#   git-sync-empty-commits.sh

set -euo pipefail

# Specify the start date for syncing commits (format: YYYY-MM-DD)
START_DATE="2025-02-20"

# Folder containing all repositories to sync
SOURCE_REPOS_DIR="$HOME/Dev/Projects/Work"

# Company name for commit messages
COMPANY_NAME="My Company"

# Author information for filtering commits
SOURCE_AUTHOR_EMAIL="john.doe@my-company.com"

# Set the target repository URL
TARGET_REPO_URL="git@github.com:john-doe/my-repository.git"

# Author information for creating fake commits
TARGET_AUTHOR_NAME="John Doe"
TARGET_AUTHOR_EMAIL="john.doe@my-company.com"

# Function to sync commits from a single repo
sync_repo() {
    local repo_path=$1
    local project_name=$(basename "$repo_path")
    local temp_dir=$(mktemp -d)

    echo "Syncing repository: $project_name"

    # Clone the target repository into the temporary directory
    git clone "$TARGET_REPO_URL" "$temp_dir"

    # Change directory to the cloned target repository
    cd "$temp_dir" || exit

    # Extract commit logs from the source repository by filtering commits made by the specified author and date
    cd "$repo_path" || exit
    git log --all --author="$SOURCE_AUTHOR_EMAIL" --since="$START_DATE" --reverse --pretty=format:"%H %ad" --date=iso > "$temp_dir/commits.txt"

    # Change directory back to the cloned target repository
    cd "$temp_dir" || exit

    # Replay each commit in the target repository with the original commit date and correct author information
    while read -r commit_hash commit_date; do
        GIT_AUTHOR_NAME="$TARGET_AUTHOR_NAME" \
        GIT_AUTHOR_EMAIL="$TARGET_AUTHOR_EMAIL" \
        GIT_COMMITTER_DATE="$commit_date" \
        git commit --allow-empty --date="$commit_date" -m "Commit on $project_name (for $COMPANY_NAME)"
    done < "$temp_dir/commits.txt"

    # Push the fake commits to target repository
    git push origin main

    # Clean up
    cd ..
    rm -rf "$temp_dir"

    echo "Retroactive sync completed for $project_name."
}

# Iterate over all repositories in the specified folder
for repo_path in "$SOURCE_REPOS_DIR"/*; do
    if [ -d "$repo_path/.git" ]; then
        sync_repo "$repo_path"
    fi
done

echo "All $COMPANY_NAME repositories from source $SOURCE_REPOS_DIR have been synced to target repository."
