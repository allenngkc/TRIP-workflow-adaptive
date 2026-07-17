#!/usr/bin/env bash
# Public Luna implementation resume entry point. The original start selected
# workspace-write; Codex resume inherits that sandbox.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
CODEX_FLOW=implementation
export STATE_DIR CODEX_FLOW
exec bash "$SCRIPT_DIR/../../codex-plan-review/scripts/_resume.sh" "$@"
