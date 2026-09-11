{
  sharedBase,
  primaryBase,
  readOnlyBash,
  ghCustomToolsReadOnly,
  denyDatadog,
  denyTicketWrites,
  ...
}: {
  build.permission =
    primaryBase
    // {
      edit = "allow";
      # The one agent allowed to request work on the host — signing a commit
      # is the expected case. Still prompts every time.
      host_exec = "ask";
    };

  plan.permission =
    primaryBase
    // {
      edit = "deny";
    }
    // ghCustomToolsReadOnly;

  pair = {
    mode = "primary";
    description = "Read-only pairing companion: discusses, investigates, and points at code in your editor via highlights and virtual text, but never edits.";
    permission =
      primaryBase
      // ghCustomToolsReadOnly
      // {
        edit = "deny";
        nvim_find_and_replace_buf = "deny";
        nvim_write_full_buf = "deny";
        nvim_send_keys = "deny";
        nvim_send_command = "ask";
        # Only delegate to read-only investigators. Denied subagents
        # are stripped from the Task tool description, so this also
        # trims context. (`general`/`test-writer` would edit.)
        task = {
          "*" = "deny";
          explore = "allow";
          reviewer = "allow";
          tickets = "allow";
          troubleshoot = "allow";
        };
      };
  };

  troubleshoot.permission =
    sharedBase
    // {
      edit = "deny";
      bash = readOnlyBash;
      "datadog_*" = "allow";
    }
    // ghCustomToolsReadOnly;

  tickets.permission =
    sharedBase
    // {
      edit = "deny";
      bash = readOnlyBash;
      "linear_*" = "ask";
      "Notion_*" = "ask";
    }
    // ghCustomToolsReadOnly;

  reviewer.permission =
    sharedBase
    // {
      edit = "deny";
      bash = readOnlyBash;
    }
    // ghCustomToolsReadOnly
    // denyDatadog
    // denyTicketWrites;

  "test-writer".permission =
    primaryBase
    // {
      edit = "ask";
    };
}
