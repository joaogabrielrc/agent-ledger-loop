#!/usr/bin/env bash
#
# loop.sh — one agent process per phase, fresh context every time.
#
# State does NOT live in the model's context. It lives in LEDGER.md and in git.
# That is why this survives compaction, a crash, a reboot and you closing the
# terminal. A dead process cannot restart itself with a clean context, so
# something outside has to call it again. This while-loop is that something.
#
# Stop condition: `ledger.sh remaining` prints 0.
# Emergency stop:  touch STOP     (finishes the current phase, then exits)
#
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 1

STOP_FILE="STOP"
LOCK="/tmp/agent-loop.lock"
LOG="/tmp/agent-loop-$(date +%Y%m%d-%H%M%S).log"

MODEL="opus"          # never a smaller model for implementation work
EFFORT="xhigh"        # low | medium | high | xhigh | max
CONTEXT_WINDOW=900000 # compact at 900k of a 1M window, i.e. 90%

MAX_ATTEMPTS=5        # attempts on the SAME line before giving up
MAX_ROUNDS=150        # absolute ceiling, against an infinite loop
GAP_SECONDS=15        # between rounds
BACKOFF_SECONDS=300   # after the CLI exits non-zero (usage limit, network)

say() { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$LOG"; }

# --------------------------------------------------------------- preconditions
[ -f LEDGER.md ] || { echo "LEDGER.md not found"; exit 1; }
command -v claude >/dev/null || { echo "claude CLI not on PATH"; exit 1; }
command -v flock  >/dev/null || { echo "flock not available"; exit 1; }

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)"
say "branch: $BRANCH"

if [ -e "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  echo "another loop.sh is already running (pid $(cat "$LOCK")). Aborted."; exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"; say "loop stopped"; exit 130' INT TERM
trap 'rm -f "$LOCK"' EXIT
rm -f "$STOP_FILE"

# ------------------------------------------------------------------- preflight
# Prove the flags work BEFORE running for hours. One tiny call beats discovering
# an invalid flag after the first phase already burned half an hour.
say "preflight: checking flags and model"
PREFLIGHT="$(claude -p --model "$MODEL" --effort "$EFFORT" \
  --permission-mode auto --permission-prompts none \
  --autocompact "$CONTEXT_WINDOW" --output-format text \
  "Use no tools. Reply with exactly: PREFLIGHT_OK" 2>&1)"
case "$PREFLIGHT" in
  *PREFLIGHT_OK*) say "preflight OK" ;;
  *) say "preflight FAILED. CLI output:"; printf '%s\n' "$PREFLIGHT" | tee -a "$LOG"; exit 1 ;;
esac

# ------------------------------------------------------------------------ loop
say "start. remaining: $(./ledger.sh remaining). log: $LOG"

LAST_LINE=""; ATTEMPTS=0; ROUNDS=0

while [ "$(./ledger.sh remaining)" -gt 0 ]; do
  [ -f "$STOP_FILE" ] && { say "stop file present. Exiting cleanly."; break; }

  ROUNDS=$((ROUNDS + 1))
  [ "$ROUNDS" -gt "$MAX_ROUNDS" ] && { say "ceiling of $MAX_ROUNDS rounds reached."; break; }

  LINE="$(./ledger.sh next)"
  if [ "$LINE" = "$LAST_LINE" ]; then ATTEMPTS=$((ATTEMPTS + 1)); else ATTEMPTS=1; LAST_LINE="$LINE"; fi

  if [ "$ATTEMPTS" -gt "$MAX_ATTEMPTS" ]; then
    say "same line failed $MAX_ATTEMPTS times without moving: $LINE"
    say "stopping. Read $LOG before restarting."
    break
  fi

  SESSION="$(uuidgen)"
  say "round $ROUNDS, attempt $ATTEMPTS/$MAX_ATTEMPTS: $LINE"
  say "session: $SESSION  (inspect later with: claude --resume $SESSION)"
  HEAD_BEFORE="$(git rev-parse HEAD)"

  claude -p \
    --model "$MODEL" --effort "$EFFORT" \
    --permission-mode auto --permission-prompts none \
    --autocompact "$CONTEXT_WINDOW" \
    --session-id "$SESSION" \
    --output-format text \
    "$(cat PHASE_PROMPT.md)" \
    2>&1 | tee >(grep -vE '^Permission (allow|deny) rule' >> "$LOG")

  STATUS=${PIPESTATUS[0]}
  HEAD_AFTER="$(git rev-parse HEAD)"

  if [ "$STATUS" -ne 0 ]; then
    say "claude exited $STATUS. Waiting ${BACKOFF_SECONDS}s."
    sleep "$BACKOFF_SECONDS"; continue
  fi

  if [ "$HEAD_BEFORE" = "$HEAD_AFTER" ]; then
    say "no new commits this round."
  else
    say "new commits: $(git rev-list --count "$HEAD_BEFORE..$HEAD_AFTER")"
  fi

  say "remaining: $(./ledger.sh remaining)"
  sleep "$GAP_SECONDS"
done

say "end. remaining: $(./ledger.sh remaining)"
./ledger.sh show | tee -a "$LOG"
