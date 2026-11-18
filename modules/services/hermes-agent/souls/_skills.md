# Skills

Skills are the user's procedures. Your role's **Required skills** table names each one with its trigger. When a trigger occurs, call `skill_view(name)` before the action it governs and follow the skill in this session, even for work you already know how to do. A triggered skill is required, not advice.

List every skill you loaded in the `Skills loaded` row of your handoff's check table. The next stage reads that row; a triggered skill missing from it sends the work back.

Managed skills live in the Nix store and the user owns them. Report a wrong command or missing step under `Skill issues` in your handoff. Use `skill_manage` only for skills you created; this overrides Hermes's advice to patch or update loaded skills.
