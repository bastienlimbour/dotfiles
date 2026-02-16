#!/bin/bash

# This script changes the author and committer email on all commits on the main branch.
# It uses git filter-branch to rewrite the history and creates a backup branch.
#
# Usage:
#   git-change-author-email.sh
#
# Example:
#   git-change-author-email.sh

set -eufo pipefail

NEW_EMAIL="bastien.limbour.dev@gmail.com"
BRANCH="main"

echo "🔍 Checking the Git repository..."

# Check if we are in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: not in a Git repository"
    exit 1
fi

# Check if we are on the main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "⚠️  Attention: you are not on the $BRANCH branch"
    echo "   Current branch: $CURRENT_BRANCH"
    read -p "Do you want to switch to $BRANCH? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git checkout "$BRANCH" || exit 1
    else
        echo "Operation cancelled."
        exit 1
    fi
fi

# Create a backup branch
BACKUP_BRANCH="backup-before-email-change-$(date +%s)"
git branch "$BACKUP_BRANCH"
echo "✅ Backup branch created: $BACKUP_BRANCH"

echo ""
echo "📧 Modification de l'email pour tous les commits..."
echo "   New email: $NEW_EMAIL"
echo ""
echo "⚠️  This operation will rewrite the entire Git history of the $BRANCH branch."
echo "   A backup branch has been created: $BACKUP_BRANCH"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

echo ""
echo "🔄 Rewriting the history..."

# Use git filter-branch to change the email
git filter-branch --force --env-filter "
    export GIT_AUTHOR_EMAIL='$NEW_EMAIL'
    export GIT_COMMITTER_EMAIL='$NEW_EMAIL'
" --tag-name-filter cat -- --branches=$BRANCH

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Email changed successfully for all commits on the $BRANCH branch!"
    echo ""
    echo "📊 Checking the changes..."
    echo ""
    echo "Sample of the latest commits:"
    git log --format="  %h - %an <%ae> - %s" -5
    echo ""
    echo "💡 To restore the old history:"
    echo "   git reset --hard $BACKUP_BRANCH"
    echo ""
    echo "⚠️  To push the changes (force push required):"
    echo "   git push --force-with-lease origin $BRANCH"
    echo ""
    echo "   Make sure no one else is working on this repo!"
else
    echo ""
    echo "❌ Error changing the email"
    echo "   To restore: git reset --hard $BACKUP_BRANCH"
    exit 1
fi
