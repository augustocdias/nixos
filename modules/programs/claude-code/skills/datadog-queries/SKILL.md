---
name: datadog-queries
description: How to approach Datadog investigations effectively — defer to the Datadog MCP's own skill guides for query syntax. Use when starting any Datadog logs/traces/metrics/RUM investigation.
---

# Datadog investigation approach

The Datadog MCP ships its own extensive, always-current skill catalog
(`list_datadog_skills` returns ~90 domain guides with the real query syntax,
attributes, and footguns). **Those are the source of truth for syntax** — do
not hand-roll query DSL from memory. This skill only captures the workflow and
this org's conventions.

## Workflow

1. **Skill discovery first.** In parallel: `load_datadog_skill` for the obvious
   domain (`datadog/logs`, `datadog/traces`, `datadog/metrics`, `datadog/rum`,
   `datadog/incidents-and-alerting`) and `list_datadog_skills` with fuzzy topic
   keywords. Load matches + their related skills. Add `datadog/visualizations`
   when charting.
2. **Pin the timeframe** explicitly and state it. Start narrow around the
   symptom; widen only if needed.
3. **Signal chain, not scattershot:** logs (what failed) → traces (where in the
   path) → metrics (how widespread) → `get_change_stories` (what changed).
4. **Aggregate before raw inspection.** Use `aggregate_*` to find the shape
   (top services, error rate, p95 by endpoint) before pulling raw
   events/spans/logs.
5. **Quantify every claim** with a query result.

## Org conventions

<!-- Fill these in as you learn them, so investigations start from the right
     scope instead of rediscovering it each time: -->

- Primary env tag(s): _TODO (e.g. `env:prod`, region tags)_
- Key services / service naming: _TODO_
- Common dashboards / notebooks to check first: _TODO_
- Standard EU site — MCP endpoint is `mcp.datadoghq.eu`.

## Output

Lead with the likely root cause + confidence, then evidence (queries + numbers)
+ timeframe + scope, then recommended fixes (described, not applied). Offer to
persist findings as a Datadog notebook when they're worth keeping.
