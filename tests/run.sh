#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/tests/test-skill-structure.sh"
bash "$ROOT/tests/test-trip-classify.sh"
bash "$ROOT/tests/test-codex-progress.sh"
bash "$ROOT/tests/test-codex-launchers.sh"

echo "all tests: PASS"
