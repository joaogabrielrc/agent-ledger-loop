# DECISIONS

An ambiguous business rule **does not stop the loop**. It is written here, the most
conservative reading is adopted, the assumption goes into the commit message, and the
work continues.

This is not an inbox of questions waiting on you. It is a journal of decisions already
taken, that you can reverse. Nothing here is blocking. You are the reviewer, not the
unblocker.

**The conservative reading is always the same rule:** when porting, behave like the
system being replaced. When building new, choose the option that is cheapest to reverse.

Each entry has three parts, and the third is the one that matters:

---

## 1. <One-line claim, with the phase and the word "measured" if it was>

**Measured.** What was actually observed. Commands run, files read, numbers. No
speculation in this section.

**Open.** The question only a human can answer, stated as a question.

**Assumption adopted (conservative).** What the implementation did, and what it costs if
this turns out to be wrong.

---

## Reviewing this file

Do not read it end to end. Triage:

```bash
# entries that pose a direct question (a decision is genuinely open)
grep -c '^## ' DECISIONS.md
```

Most entries are measured facts you only need to know about. A minority pose a real
question. Of those, a handful are expensive if the assumption is wrong: they touch money,
data loss, or something a user sees.

**The cost of reversing an assumption grows with time.** An entry reviewed today changes
one file. The same entry three phases later changes five. So triage by cost, not by order.

**A decision only becomes code when it becomes a line in the LEDGER.** Writing the answer
here does nothing: the loop reads `LEDGER.md`, not this file.

```bash
printf 'PENDING  R1  the-decision-as-a-phase-name\n' | ./ledger.sh insert-before <ANCHOR>
```
