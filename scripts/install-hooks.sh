#!/usr/bin/env bash
# Install git hooks from .githooks/ into .git/hooks/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    echo "Error: Not a git repository" >&2
    exit 1
fi

# Use git's core.hooksPath to point to .githooks/
git -C "$PROJECT_DIR" config core.hooksPath .githooks
echo "Git hooks path set to .githooks/"

# Ensure hooks are executable
chmod +x "$PROJECT_DIR"/.githooks/* 2>/dev/null || true
echo "Hooks installed successfully."
