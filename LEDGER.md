# LEDGER

Single source of truth for what is done and what is left. A model's context is lost to
compaction. This file is not.

## Stop condition

```bash
./ledger.sh remaining     # the program is finished only when this prints 0
```

Shipping one phase does not finish the program. Green tests do not finish the program.
A confident report does not finish the program. Only the zero does.

## Status vocabulary

| Status | Meaning |
|---|---|
| `DONE` | Plan committed, tasks committed, gate at exit 0. The hash is on the line. |
| `PENDING` | Not delivered. Counts toward the stop condition. |
| `MANUAL` | A human runs this. Does not count toward the stop condition. |

## Rules

1. A line becomes `DONE` only with the gate at exit 0. The hash goes on the line, in the
   same commit.
2. A phase too big for one turn is split, and **each sub-phase becomes a new line before
   the first one starts**. Splitting means adding lines, never deleting them. The count
   going up means scope became visible, not that scope grew.
3. Never delete a line. Status only moves forward.
4. All reads and writes go through `./ledger.sh`.
5. An ambiguous business rule does not stop the loop. It goes to `DECISIONS.md`.

## Status

```
DONE     P0    project-skeleton-and-gate     a1b2c3d
PENDING  P1    first-real-phase
PENDING  P2    second-phase
MANUAL   P9    production-cutover
```
