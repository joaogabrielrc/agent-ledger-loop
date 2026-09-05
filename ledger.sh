#!/usr/bin/env bash
#
# ledger.sh — the ONLY write path to LEDGER.md.
#
# Why it exists: the ledger has several independent writers (the loop, the agent
# inside each round, you at the keyboard). They all read-modify-write the whole
# file. Without a lock, whoever read first and wrote last silently erases the
# other. Measured on this exact file shape: of 20 concurrent writes, 1 survived.
# Through this gate: 20 of 20.
#
# Usage:
#   ledger.sh next                    # first PENDING line
#   ledger.sh remaining               # how many PENDING
#   ledger.sh show                    # the whole status block
#   ledger.sh done <ID> <commit>      # PENDING <ID> becomes DONE with the hash
#   ledger.sh insert-before <ID>      # reads new lines from stdin
#
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 1

# LEDGER_FILE lets the test suite run against a copy.
LEDGER="${LEDGER_FILE:-LEDGER.md}"
LOCK="$ROOT/.ledger.lock"
WAIT_SECONDS=120

read_lock()  { exec 9<>"$LOCK"; flock -s -w "$WAIT_SECONDS" 9 || { echo "ledger.sh: lock timeout (read)" >&2; exit 75; }; }
write_lock() { exec 9<>"$LOCK"; flock -x -w "$WAIT_SECONDS" 9 || { echo "ledger.sh: lock timeout (write)" >&2; exit 75; }; }

case "${1:-}" in
  next)       read_lock; grep -m1 '^PENDING' "$LEDGER" ;;
  remaining)  read_lock; grep -c '^PENDING' "$LEDGER" ;;
  show)       read_lock; grep -E '^(DONE|PENDING|MANUAL)' "$LEDGER" ;;

  done)
    [ $# -eq 3 ] || { echo "usage: ledger.sh done <ID> <commit>" >&2; exit 2; }
    write_lock
    ID="$2" SHA="$3" python3 - "$LEDGER" <<'PY'
from pathlib import Path
import os, re, sys
identifier, commit = os.environ["ID"], os.environ["SHA"]
path = Path(sys.argv[1]); text = path.read_text(encoding="utf-8")
match = re.search(rf'^PENDING(\s+){re.escape(identifier)}(\s+)(\S.*?)\s*$', text, re.M)
if not match:
    print(f"ledger.sh: no PENDING line for '{identifier}'", file=sys.stderr); sys.exit(1)
line = f"DONE   {match.group(1)}{identifier}{match.group(2)}{match.group(3)}  {commit}"
path.write_text(text[:match.start()] + line + text[match.end():], encoding="utf-8")
print(line)
PY
    ;;

  insert-before)
    [ $# -eq 2 ] || { echo "usage: ledger.sh insert-before <ID>   (new lines on stdin)" >&2; exit 2; }
    LINES="$(cat)"
    [ -n "$LINES" ] || { echo "ledger.sh: empty stdin, nothing inserted" >&2; exit 2; }
    write_lock
    ID="$2" LINES="$LINES" python3 - "$LEDGER" <<'PY'
from pathlib import Path
import os, re, sys
identifier = os.environ["ID"]; new = os.environ["LINES"].rstrip("\n") + "\n"
path = Path(sys.argv[1]); text = path.read_text(encoding="utf-8")
match = re.search(rf'^(PENDING|DONE|MANUAL)\s+{re.escape(identifier)}\s+.*$', text, re.M)
if not match:
    print(f"ledger.sh: anchor line '{identifier}' not found", file=sys.stderr); sys.exit(1)
path.write_text(text[:match.start()] + new + text[match.start():], encoding="utf-8")
print(f"inserted {len(new.splitlines())} line(s) before {identifier}")
PY
    ;;

  *) sed -n '9,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
