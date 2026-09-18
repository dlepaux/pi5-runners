#!/bin/bash
# ============================================================================
# Every suite. What CI runs.
# ============================================================================
# NOT `set -e`. Each suite is independent and cheap, so all of them run and the
# summary lists everything that failed -- a run that stops at the first failure tells
# you one thing when it could have told you five.
# ============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAILED=""
for suite in board-assets assets fit parts clips airflow print; do
    echo ""
    echo "=============================================================="
    echo "  $suite"
    echo "=============================================================="
    if ! "./scripts/test-$suite.sh"; then
        FAILED="$FAILED $suite"
    fi
done

# The fan mode sets the module's length: every geometry suite again, in the other one.
for suite in fit clips airflow; do
    echo ""
    echo "=============================================================="
    echo "  $suite (NF-A4x20)"
    echo "=============================================================="
    if ! FAN_MODEL=NF-A4x20 "./scripts/test-$suite.sh"; then
        FAILED="$FAILED $suite(NF-A4x20)"
    fi
done

echo ""
if [ -z "$FAILED" ]; then
    echo "✅ all suites passed"
    exit 0
fi
echo "❌ failed suites:$FAILED"
exit 1
