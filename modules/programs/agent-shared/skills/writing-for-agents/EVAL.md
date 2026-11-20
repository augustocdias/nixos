# Blind evaluation of a document change

Use this when a wording change to a skill or another agent document must change what agents do, and building the bundle and checking discovery cannot show that it does. It costs two or more agent runs plus a judge per comparison, so reserve it for wording that drives behavior.

## Blinding

- The candidates see an organic task. No directory, file or prompt they read contains `eval`, `test`, `judge`, `experiment`, `rubric`, `score`, `compare`, `benchmark` or `candidate`.
- Do not tell a candidate that other candidates exist, and do not ask it to list the skills or files it used.
- The judge knows it is judging but sees outputs only by neutral labels, never by variant or model.

## Steps

1. **Frame.** Name the variant under test (old wording against new wording) and write 3–6 concrete criteria for the behavior that counts as success. Only the judge sees the criteria.
2. **Prepare environments.** Give each candidate its own scratch directory under `<absolute-workspace>/prototypes/<slug>/`, with project-shaped names and the document variant installed where the harness discovers it. Plant the context the real task would have.
3. **Write one prompt.** Phrase it the way the user would type the real request.
4. **Run the candidates.** Spawn fresh-context subagents subject to the harness delegation rules, one per variant, with the same prompt. Ask the user which agents or models to use when more than the default would help.
5. **Judge.** Spawn one judge with the criteria and the labelled outputs. One judge scores every output in a single pass on one scale.
6. **Check the transcripts.** Read each candidate's session record and grade what it actually read and did, not what it says it did.
7. **Compare.** Read every output yourself and compare with the judge. Disagreement means a biased judge or ambiguous criteria; resolve it before you conclude.

Report the variant, the criteria, the per-candidate notes, the judge's verdict, your own reading, and whether to keep the new wording.
