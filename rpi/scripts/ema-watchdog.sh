#!/usr/bin/env bash
# EMA System & Container Watchdog Daemon
# Checks application health and automatically recovers containers if unresponsive.

set -euo pipefail

HEALTH_URL="http://127.0.0.1:8000/api/health"
DASHBOARD_URL="http://127.0.0.1:8080"
EMA_DIR="/opt/ema"
MAX_FAILURES=3
CHECK_INTERVAL_SEC=30
TIMEOUT_SEC=10

failure_count=0

log() {
    echo "[$(date -Iseconds)] [EMA-WATCHDOG] $*"
}

check_endpoint() {
    local url="$1"
    curl -sSf --max-time "$TIMEOUT_SEC" "$url" >/dev/null 2>&1
}

log "Starting EMA health watchdog daemon (Interval: ${CHECK_INTERVAL_SEC}s, Max Failures: ${MAX_FAILURES})..."

while true; do
    if check_endpoint "$HEALTH_URL" && check_endpoint "$DASHBOARD_URL"; then
        if [ "$failure_count" -gt 0 ]; then
            log "Service recovered successfully. Resetting failure counter."
            failure_count=0
        fi
    else
        failure_count=$((failure_count + 1))
        log "WARNING: Health check failed (${failure_count}/${MAX_FAILURES})"
        
        if [ "$failure_count" -ge "$MAX_FAILURES" ]; then
            log "CRITICAL: Service unresponsive after ${MAX_FAILURES} consecutive checks. Restarting stack..."
            cd "$EMA_DIR" || exit 1
            docker compose restart || docker compose up -d
            failure_count=0
            log "Restart initiated. Pausing 45 seconds for container warmup..."
            sleep 45
            continue
        fi
    fi

    sleep "$CHECK_INTERVAL_SEC"
done
