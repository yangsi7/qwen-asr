#!/usr/bin/env bash
# Claude Code hook: guard against committing sensitive files
set -euo pipefail

SENSITIVE_PATTERNS=(".env" ".mcp.json" "*.safetensors" "*.bin" "*.key" "*.pem")

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if git diff --cached --name-only 2>/dev/null | grep -q "$pattern"; then
        echo "GUARD: Sensitive file matching '$pattern' staged for commit."
        echo "Remove it from staging: git reset HEAD <file>"
        exit 1
    fi
done
