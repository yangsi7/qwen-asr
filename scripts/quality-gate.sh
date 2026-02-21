#!/usr/bin/env bash
# Quality gate: build + smoke tests for CI and local validation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Quality Gate ==="
echo ""

# Build check
echo "[Build]"
check "make blas compiles" bash -c "cd '$PROJECT_DIR' && make blas"
check "binary exists" test -x "$PROJECT_DIR/qwen_asr"
check "binary is ARM64" bash -c "file '$PROJECT_DIR/qwen_asr' | grep -q arm64"

# Binary sanity
echo ""
echo "[Binary]"
check "--help flag works" bash -c "'$PROJECT_DIR/qwen_asr' --help 2>&1 | grep -q 'Usage'"

# Model check
echo ""
echo "[Model]"
check "0.6B model dir exists" test -d "$PROJECT_DIR/qwen3-asr-0.6b"
check "model.safetensors present" test -f "$PROJECT_DIR/qwen3-asr-0.6b/model.safetensors"
check "vocab.json present" test -f "$PROJECT_DIR/qwen3-asr-0.6b/vocab.json"

# Scripts check
echo ""
echo "[Scripts]"
check "transcribe.sh exists" test -f "$PROJECT_DIR/scripts/transcribe.sh"
check "transcribe.sh executable" test -x "$PROJECT_DIR/scripts/transcribe.sh"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
