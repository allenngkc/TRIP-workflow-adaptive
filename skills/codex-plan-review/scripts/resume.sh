#!/usr/bin/env bash
# Public review resume entry point. Selects Sol explicitly, then delegates to
# the shared low-level resume mechanics.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_FLOW=review
export CODEX_FLOW
exec bash "$SCRIPT_DIR/_resume.sh" "$@"
