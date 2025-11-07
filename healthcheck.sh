#!/bin/bash
###############################################################################
# GitHub Action Runner - Health Check Script
# Purpose: Check runner health status
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths
RUNNER_DIR="${RUNNER_DIR:-.}"
RUNNER_CONFIG="$RUNNER_DIR/.runner"
RUNNER_PID_FILE="/tmp/runner.pid"

# Check if runner configuration exists
if [[ ! -d "$RUNNER_CONFIG" ]]; then
    echo -e "${YELLOW}⚠${NC} Runner not configured yet"
    exit 1
fi

# Check if runner process is running
if [[ -f "$RUNNER_PID_FILE" ]]; then
    PID=$(cat "$RUNNER_PID_FILE")
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} Runner process not running (PID: $PID)"
        exit 1
    fi
fi

# Check runner connectivity (optional - check GitHub API)
if command -v curl &> /dev/null; then
    if ! curl -sf https://github.com/api/v3 > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} Cannot reach GitHub API"
        exit 0  # Don't fail on network issues
    fi
fi

# Check if runner service process exists
if ! pgrep -f "Runner.Server" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Runner service not responding"
    exit 0  # Warn but don't fail
fi

echo -e "${GREEN}✓${NC} Runner is healthy"
exit 0

