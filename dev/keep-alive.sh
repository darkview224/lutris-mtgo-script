#!/usr/bin/env bash
# Runs an unattended Claude Code agentic session against this repo's HANDOFF.md,
# automatically relaunching (via --continue) whenever the process exits — whether
# that's from finishing a chunk of work, hitting a usage-window limit, or any
# other reason. No need to guess when a 5-hour limit window resets: a relaunch
# attempt while still capped just fails fast and tries again after a short sleep,
# which costs nothing meaningful.
#
# Usage: run this from inside the repo directory, inside a `tmux` or `screen`
# session so it survives you closing the terminal / going to bed:
#
#   tmux new -s mtgo
#   ./keep-alive.sh
#   [detach with Ctrl+B then D]
#
# Reattach in the morning with: tmux attach -t mtgo
#
# WARNING: this passes --dangerously-skip-permissions, meaning Claude Code will
# NOT ask before running any command. Only run this on a machine you're
# comfortable giving that level of unattended access to.

set -uo pipefail

LOG_FILE="${LOG_FILE:-$HOME/mtgo-agent.log}"
SLEEP_BETWEEN_ATTEMPTS="${SLEEP_BETWEEN_ATTEMPTS:-60}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "keep-alive loop starting"

FIRST=1
while true; do
  if [ "$FIRST" = "1" ]; then
    log "Launching initial Claude Code session"
    claude --dangerously-skip-permissions -p \
      "Read HANDOFF.md in this repo and carry out the work it describes, autonomously, to completion or to a documented dead end. Do not stop to ask me anything."
    FIRST=0
  else
    log "Relaunching (continuing previous session)"
    claude --dangerously-skip-permissions --continue -p "continue"
  fi
  STATUS=$?
  log "claude exited with status $STATUS"
  log "Sleeping ${SLEEP_BETWEEN_ATTEMPTS}s before next attempt"
  sleep "$SLEEP_BETWEEN_ATTEMPTS"
done
