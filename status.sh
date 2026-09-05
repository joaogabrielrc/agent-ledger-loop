#!/usr/bin/env bash
# Answers "is it finished?" definitively.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
LOG="$(ls -t /tmp/agent-loop-*.log 2>/dev/null | head -1)"
LEFT=$(./ledger.sh remaining)
DONE=$(grep -c '^DONE' LEDGER.md)
CEILING=$(grep -m1 '^MAX_ROUNDS=' loop.sh | tr -dc '0-9')
ROUNDS=$(grep -c 'round [0-9]*, attempt' "$LOG" 2>/dev/null || echo 0)

# The real pid comes from the lock file the loop writes, never from pgrep:
# short-lived children of a round also match "loop.sh".
PID=$(cat /tmp/agent-loop.lock 2>/dev/null)
ALIVE=0; [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null && ALIVE=1

echo "remaining: $LEFT   |   done: $DONE   |   rounds: $ROUNDS of $CEILING"
echo
if [ "$ALIVE" = 1 ]; then
  echo "STILL RUNNING (pid $PID)"
  grep -E '^20[0-9]{2}-.*(round [0-9]*,|remaining:)' "$LOG" | tail -2
elif [ "$LEFT" -eq 0 ]; then
  echo "FINISHED. No PENDING lines left."
else
  echo "STOPPED WITHOUT FINISHING. Reason in the last lines:"
  grep -E '^20[0-9]{2}-' "$LOG" 2>/dev/null | tail -3
  echo; echo "To continue from where it stopped:  ./loop.sh"
fi
