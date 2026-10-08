{
  sharedBase,
  primaryBase,
  baseBash,
  ghCustomToolsReadOnly,
  ...
}: {
  plan.permission = primaryBase // ghCustomToolsReadOnly;

  reviewer.permission =
    sharedBase
    // {
      edit = "deny";
      bash = baseBash;
    }
    // ghCustomToolsReadOnly;

  "test-writer".permission =
    primaryBase
    // {
      edit = "ask";
    };
}
