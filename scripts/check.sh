#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_ROOT/.build/module-cache"
TASK_SWIFT_FLAGS=(--disable-sandbox --cache-path "$TASK_ROOT/.build/cache" --config-path "$TASK_ROOT/.build/config" --security-path "$TASK_ROOT/.build/security")
swift test "${TASK_SWIFT_FLAGS[@]}"
swift build "${TASK_SWIFT_FLAGS[@]}"
python3 scripts/test_worker.py
