#!/usr/bin/env bash
# Reproduces the measurement in the README: the same 20 concurrent writes, with and
# without the lock. Run it before you trust rule 6.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
WRITERS=20

echo "== RED: $WRITERS concurrent writes, no lock (what an agent does today)"
cp LEDGER.md /tmp/race-red.md
cat > /tmp/race-writer.py <<'PY'
# Read the whole file, modify, write the whole file back. No lock.
from pathlib import Path
import sys, time
path = Path("/tmp/race-red.md"); tag = sys.argv[1]
text = path.read_text(encoding="utf-8")   # read
time.sleep(0.05)                          # the time the agent spends thinking
anchor = "PENDING  P2"
text = text.replace(anchor, f"PENDING  {tag}    race-test\n{anchor}", 1)
path.write_text(text, encoding="utf-8")   # write it all back
PY
for i in $(seq -w 1 $WRITERS); do python3 /tmp/race-writer.py "R$i" & done; wait 2>/dev/null
RED=$(grep -c '^PENDING  R[0-9]' /tmp/race-red.md)
echo "   expected $WRITERS, survived: $RED"

echo
echo "== GREEN: the same $WRITERS writes through ledger.sh (flock)"
cp LEDGER.md /tmp/race-green.md
for i in $(seq -w 1 $WRITERS); do
  printf "PENDING  G$i    race-test\n" | LEDGER_FILE=/tmp/race-green.md ./ledger.sh insert-before P2 >/dev/null &
done; wait 2>/dev/null
GREEN=$(grep -c '^PENDING  G[0-9]' /tmp/race-green.md)
UNIQUE=$(grep -o '^PENDING  G[0-9]*' /tmp/race-green.md | sort -u | wc -l)
echo "   expected $WRITERS, survived: $GREEN (unique: $UNIQUE)"

echo
if [ "$GREEN" -eq "$WRITERS" ] && [ "$RED" -lt "$WRITERS" ]; then
  echo "PASS: the lock is doing something. Without it $((WRITERS - RED)) writes vanished silently."
  exit 0
else
  echo "INCONCLUSIVE: red=$RED green=$GREEN. On a slower machine the red run may not lose writes;"
  echo "raise the sleep in /tmp/race-writer.py and run again."
  exit 1
fi
