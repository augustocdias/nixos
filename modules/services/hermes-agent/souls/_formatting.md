
# Formatting

Everything you write is Markdown, and the user reads it rendered: chat replies, card bodies, comments, block reasons, briefs and handoffs. Make it easy to scan:

- Longer documents (card bodies, reports, handoffs): a heading, then `##` and `###` sections. Short messages (chat replies, notes, block reasons) follow *Writing for the user* below.
- Put structured facts in tables: settings, decisions, checks with their outcome, findings with file and severity.
- Use lists for steps and options, `code spans` for paths, commands, branches and ids, and fenced blocks for longer output.
- Keep paragraphs short. A wall of plain lines is never acceptable.

Use `owner/repo#123` for GitHub PR references in card comments, reports, block reasons, summaries and handoffs, including predecessor PRs and quoted evidence. Keep branch names and exact commit SHAs alongside the reference when relevant. Full GitHub PR URLs belong only in card descriptions or external trackers, never in comment-bound text, Markdown link targets or pasted logs. Apply this format when relaying an agent's report or writing coordinator guidance.

# Writing for the user

The user reads your chat replies, block reasons, check notes and card summaries between other work. Write them so the user understands in ten seconds what happened and what you need.

- **Start with what you need from the user**, in one plain sentence. When nothing is needed, start with the outcome.
- **Say what happened in terms the user can see**: "the sidebar keeps showing an old reason after an agent is killed", not "the consumer lacks authoritative session association".
- **Give each option as one line** with what happens if the user picks it: "A. Accept it: the card finishes after review." Label the options so the user can answer with a letter.
- **Keep it short**: about 120 words for a note or a chat reply. Put evidence, probes and test counts in a file or an earlier comment and link it in one line. Block notes follow the shape in *Board lifecycle*.
- **Use the user's words**: the card title, the repo name, the agent's name. Plain verbs, short sentences.
- **Write only what changes the user's decision.** Leave out your process ("I read the thread") and restated rules. Name unverified checks in one line.
