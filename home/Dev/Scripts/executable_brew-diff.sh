#!/bin/bash

# This script compares the installed taps, brews, and casks with
# the ones in the Brewfile and prints the differences.
#
# Usage:
#   brew-diff.sh
#
# Example:
#   brew-diff.sh

set -eufo pipefail

# Path to your Brewfile
BREWFILE="$HOME/Brewfile"

# Extract taps, brews, and casks from the Brewfile
BREWFILE_TAPS=$(grep '^tap ' "$BREWFILE" | awk '{print $2}' | tr -d '"') || echo "No taps found"
BREWFILE_BREWS=$(grep '^brew ' "$BREWFILE" | awk '{print $2}' | tr -d '"') || echo "No brews found"
BREWFILE_CASKS=$(grep '^cask ' "$BREWFILE" | awk '{print $2}' | tr -d '"') || echo "No casks found"

# Installed taps, brews, and casks
INSTALLED_TAPS=$(brew tap)
INSTALLED_BREWS=$(brew list --installed-on-request --full-name)
INSTALLED_CASKS=$(brew list --cask --full-name)

# Calculate the differences
echo "=== Missing Taps ==="
for tap in $BREWFILE_TAPS; do
    if ! echo "$INSTALLED_TAPS" | grep -qx "$tap"; then
        echo "$tap"
    fi
done

echo ""

echo "=== Missing Brews ==="
for brew in $BREWFILE_BREWS; do
    if ! echo "$INSTALLED_BREWS" | grep -qx "$brew"; then
        echo "$brew"
    fi
done

echo ""

echo "=== Missing Casks ==="
for cask in $BREWFILE_CASKS; do
    if ! echo "$INSTALLED_CASKS" | grep -qx "$cask"; then
        echo "$cask"
    fi
done

echo ""

echo "=== Extra Taps ==="
for tap in $INSTALLED_TAPS; do
    if ! echo "$BREWFILE_TAPS" | grep -qx "$tap"; then
        echo "$tap"
    fi
done

echo ""

echo "=== Extra Brews ==="
for brew in $INSTALLED_BREWS; do
    if ! echo "$BREWFILE_BREWS" | grep -qx "$brew"; then
        echo "$brew"
    fi
done

echo ""

echo "=== Extra Casks ==="
for cask in $INSTALLED_CASKS; do
    if ! echo "$BREWFILE_CASKS" | grep -qx "$cask"; then
        echo "$cask"
    fi
done

echo ""
