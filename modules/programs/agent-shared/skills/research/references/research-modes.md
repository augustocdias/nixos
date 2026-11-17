# Research modes

Choose the smallest scope that supports the question. Combine the relevant checks when a task crosses modes; do not run every mode.

## Deep research

Use for broad, consequential or disputed decisions. Define the decision and success criteria before collecting evidence. Seek primary evidence and independent corroboration for the conclusions that drive the decision. Check contrary evidence and explain what would change the recommendation. Report unresolved contradictions and coverage gaps rather than treating source count as confidence.

## Repository or tool research

For adoption or comparison, inspect the implementation boundary, license, releases, maintenance, issues, installation requirements and relevant tests. Check package metadata and independent usage evidence when adoption matters. Stars, forks and downloads are proxies, not proof of production use. Distinguish documented capabilities from behavior you exercised.

For a bounded API or local-code question, inspect the owning documentation or implementation and relevant callers. Cite the version or revision and local lines where useful. Do not expand one implementation fact into an adoption review or require unrelated public corroboration.

## Community evidence

Open full threads or comments and preserve the context of complaints, workarounds and positive experiences. Look for recurring problems and contrary cases across independent sources. Corroborate a reported problem with an issue, reproduction or other observable evidence where available. Treat an isolated post as a weak signal. Summarize themes without exporting unnecessary personal identifiers.

## Live or visual evidence

Use when the answer depends on current UI state, charts, comments, filters or JavaScript-rendered content. Search and APIs can identify candidates; verify the relevant state through the harness's configured browser, DOM or image tools. Follow `terminal-browser` where the harness requires it rather than assuming Hermes tool names work everywhere.

Record what was observed, when it was observed and whether access was public, authorized internal, degraded or blocked. Missing transcripts, comments or visuals limit only the claims that depend on them. Static sources can still support independent facts.

## Monitoring design

Use only when the user asks to design recurring research. Define the sources, query scope, deduplication rule, freshness window, change threshold, no-change output, storage boundary and stop condition. Deliver the design as research findings. Creating schedules or enabling external delivery requires separate authorization.
