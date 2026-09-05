Read LEDGER.md at the repository root. Take the FIRST PENDING line and deliver ONLY that one.

This round:
1. If a plan for this phase already exists in plans/, continue from where it stopped.
   Find out where by reading 'git log --oneline -30'. Never from memory: you have none.
2. If no plan exists, write it in plans/ and commit the plan before writing code.
3. Implement task by task. A task ends green and committed, or it did not end.
4. Run the project's gate command. Send the output to a file and read the whole file,
   never through head or tail.
5. Only with the gate at exit 0: flip the line to DONE with the commit hash.
6. End your turn as soon as that SINGLE line is DONE. Do not start the next one.

LEDGER WRITES: never edit LEDGER.md with python, sed or an editor. Read-modify-write of the
whole file silently loses another process's write: measured, of 20 concurrent writes 1 survived.
Every read and every write goes through ./ledger.sh, which serialises with flock:
  ./ledger.sh next                  first PENDING line
  ./ledger.sh remaining             how many are left
  ./ledger.sh show                  the whole status block
  ./ledger.sh done <ID> <commit>    mark DONE with the hash
  printf 'PENDING  <ID>  <description>\n' | ./ledger.sh insert-before <ANCHOR-ID>

If the phase is too big for one turn, split it into sub-phases and ADD each one as a new
PENDING line BEFORE starting the first. Never shrink scope silently. Never delete a line.

Do not ask me anything. An ambiguous or missing business rule goes to DECISIONS.md: write
what you measured, what is open, and the conservative assumption you adopted. Record the
assumption in the commit message and keep going.
