# Quest fix backlog (generated / manual)

Track pattern fixes **by class**, not individual quest tickets.

| Priority | Pattern | Zone / scope | Action | Status |
|----------|---------|--------------|--------|--------|
| 1 | P05-ITEM-USE-CAPTURE | 6453 Echo Isles | Parameterised spawn-on-accept QuestScript | 24626 done |
| 2 | P09-PHASED | 6453, 6170 | Audit `conditions` type 26 vs quest ids | TODO |
| 3 | P01-KILL | Starter zones | Run sql/16 query #1 — batch spawn fixes | TODO |
| 4 | P07-CRITERIA | 6170 Wandering Isle | Needs criteria C++ scripts | TODO |
| 5 | P10-INSTANCE | Dungeons 1–20 | Cross-check instance_template entrances | TODO |

## P05 candidates in starter zones (item + kill objective)

Run:

```powershell
mysql --defaults-extra-file=setup_tmp/mysql.cnf world < sql/16_quest_audit_queries.sql
```

Or query #2 only. Each result row is a quest that may need the same fix template as Young and Vicious.

## Adding entries

When a quest is verified OK, note it in the zone catalog `zones/README.md` manual table — do not delete backlog rows; mark **Status** column.
