{
  sharedBase,
  primaryBase,
  baseBash,
  ghCustomToolsReadOnly,
  denyDatadog,
  denyTicketWrites,
  ...
}: {
  plan.permission = primaryBase // ghCustomToolsReadOnly;

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
      bash = baseBash;
      "datadog_*" = "allow";
    }
    // ghCustomToolsReadOnly;

  tickets.permission =
    sharedBase
    // {
      edit = "deny";
      bash = baseBash;
      "linear_*" = "ask";
      "Notion_*" = "ask";
    }
    // ghCustomToolsReadOnly;

  reviewer.permission =
    sharedBase
    // {
      edit = "deny";
      bash = baseBash;
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
