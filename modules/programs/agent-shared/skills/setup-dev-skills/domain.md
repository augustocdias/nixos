# Domain documents

Record this project's actual authoritative document paths here during setup. New supporting documents live in the resolved absolute `.dev-skills/` workspace; existing tracked documents remain intact and may be authoritative read-only inputs.

## Before exploration

Read workspace `GLOSSARY.md`, or `GLOSSARY-MAP.md` when it exists, then relevant context glossaries and ADRs. Also read authoritative sources recorded here. Missing optional ADRs or context maps are not a reason to invent them. The contextual `domain-modeling` skill creates meaningful entries when terms or decisions are actually resolved; manual `grill-with-docs` and `improve-codebase-architecture` can lead to it only on user invocation.

## Layout

Single context, relative to workspace:

```text
GLOSSARY.md
adr/
  0001-event-sourced-orders.md
  0002-postgres-for-write-model.md
```

Multiple real bounded contexts, only when needed:

```text
GLOSSARY-MAP.md
adr/
domains/
  ordering/
    GLOSSARY.md
    adr/
  billing/
    GLOSSARY.md
    adr/
```

The learning glossary under `teach/<topic>/` is separate from these domain glossaries.

## Vocabulary and decisions

Use terms as defined when naming concepts in tickets, refactor proposals, hypotheses, and tests. Do not drift to synonyms the glossary rejects. A missing term may mean invented language rather than a documentation gap; verify before adding it.

Surface conflicts with existing ADRs explicitly rather than overriding them silently. For example: “Contradicts ADR-0007 (event-sourced orders), but worth reopening because …”. Use the installed domain-modeling format companions for meaningful glossary/ADR updates. New supporting entries never silently modify authoritative tracked sources.
