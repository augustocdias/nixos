{jailed ? false}: let
  baseBash =
    if jailed
    then {
      "*" = "allow";
      "nix build*" = "allow";
      "nix-build" = "allow";
      "nix-build *" = "allow";
      "nix flake check*" = "allow";
      "nix-store -r*" = "allow";
      "nix-store --realise*" = "allow";
      "nix run*" = "ask";
      "nix shell*" = "ask";
      "nix develop*" = "ask";
      "nix-env*" = "deny";
      "nix profile*" = "deny";
      "nix-collect-garbage*" = "deny";
      "nixos-rebuild*" = "deny";
      "darwin-rebuild*" = "deny";
      "home-manager*" = "deny";
      "update-system*" = "deny";
      "update-nvim*" = "deny";
      "*nixos-rebuild*" = "deny";
      "*darwin-rebuild*" = "deny";
      "herdr*" = "ask";
    }
    else {
      "*" = "ask";

      # -- Nix
      "nix flake show*" = "allow";
      "nix flake metadata*" = "allow";
      "nix flake info*" = "allow";
      "nix-info" = "allow";
      "nix-info *" = "allow";
      "nix path-info*" = "allow";
      "nix show-derivation*" = "allow";
      "nix-store --query*" = "allow";
      "nix build*" = "deny";
      "nix-build*" = "deny";
      "nix run*" = "deny";
      "nix develop*" = "deny";
      "nix shell*" = "deny";
      "nix flake check*" = "deny";
      "nix-store -r*" = "deny";
      "nix-store --realise*" = "deny";
      "*nix build*" = "deny";
      "*nix-build*" = "deny";
      "*nix run*" = "deny";
      "*nix develop*" = "deny";
      "*nix shell*" = "deny";
      "*nix flake check*" = "deny";
      "nix profile*" = "deny";
      "nix-collect-garbage*" = "deny";
      "nixos-rebuild*" = "deny";
      "darwin-rebuild*" = "deny";
      "home-manager*" = "deny";
      "update-system*" = "deny";
      "update-nvim*" = "deny";
      "*nixos-rebuild*" = "deny";
      "*darwin-rebuild*" = "deny";
      "nix-env*" = "deny";

      # -- Git: core read-only
      "git status*" = "allow";
      "git log*" = "allow";
      "git show*" = "allow";
      "git diff*" = "allow";
      "git blame*" = "allow";
      "git reflog*" = "allow";
      "git describe*" = "allow";
      "git shortlog*" = "allow";
      "git whatchanged*" = "allow";

      # -- Git: plumbing / inspection
      "git rev-parse*" = "allow";
      "git symbolic-ref*" = "allow";
      "git ls-files*" = "allow";
      "git ls-remote*" = "allow";
      "git ls-tree*" = "allow";
      "git cat-file*" = "allow";
      "git rev-list*" = "allow";
      "git name-rev*" = "allow";
      "git merge-base*" = "allow";
      "git count-objects*" = "allow";
      "git fsck*" = "allow";
      "git verify-commit*" = "allow";
      "git verify-tag*" = "allow";
      "git check-ignore*" = "allow";
      "git check-attr*" = "allow";
      "git check-mailmap*" = "allow";
      "git for-each-ref*" = "allow";
      "git hash-object*" = "allow";

      # -- Git: misc read-only
      "git archive*" = "allow";
      "git bundle*" = "allow";
      "git help*" = "allow";
      "git --version*" = "allow";

      # -- Git: conditional read-only (with flags)
      "git branch --list*" = "allow";
      "git branch -l*" = "allow";
      "git branch --show-current*" = "allow";
      "git branch --contains*" = "allow";
      "git branch --merged*" = "allow";
      "git branch --no-merged*" = "allow";
      "git remote -v*" = "allow";
      "git remote show*" = "allow";
      "git remote get-url*" = "allow";
      "git tag --list*" = "allow";
      "git tag -l*" = "allow";
      "git tag --contains*" = "allow";
      "git tag --merged*" = "allow";
      "git tag --points-at*" = "allow";
      "git config --get*" = "allow";
      "git config --get-all*" = "allow";
      "git config --get-regexp*" = "allow";
      "git config --list*" = "allow";
      "git config -l*" = "allow";
      "git stash list*" = "allow";
      "git stash show*" = "allow";
      "git worktree list*" = "allow";
      "git -C * status*" = "allow";
      "git -C * log*" = "allow";
      "git -C * diff*" = "allow";
      "git -C * show*" = "allow";
      "git -C * branch --list*" = "allow";
      "git -C * branch -a*" = "allow";
      "git -C * rev-parse*" = "allow";
      "git -C * ls-files*" = "allow";
      "git -C * for-each-ref*" = "allow";

      # -- File / directory inspection
      "ls" = "allow";
      "ls *" = "allow";
      "eza" = "allow";
      "eza *" = "allow";
      # Not "tree*" — that matched tree-sitter, which generates and loads code.
      "tree" = "allow";
      "tree *" = "allow";
      "cat" = "allow";
      "cat *" = "allow";
      "bat" = "allow";
      "bat *" = "allow";
      "head" = "allow";
      "head *" = "allow";
      "tail" = "allow";
      "tail *" = "allow";
      # Not "wc*" — that matched wcurl, which writes downloads to disk.
      "wc" = "allow";
      "wc *" = "allow";
      "file" = "allow";
      "file *" = "allow";
      "stat" = "allow";
      "stat *" = "allow";
      "du" = "allow";
      "du *" = "allow";
      "df" = "allow";
      "df *" = "allow";
      "readlink" = "allow";
      "readlink *" = "allow";

      # -- Search
      "rg" = "allow";
      "rg *" = "allow";
      # Not "fd*", which also matched fdisk/fdformat.
      "fd" = "allow";
      "fd *" = "allow";
      "find" = "allow";
      "find *" = "allow";
      "find*-exec*" = "ask";
      "find*-ok*" = "ask";
      "find*-delete*" = "ask";
      "find*-fprintf*" = "ask";
      "grep" = "allow";
      "grep *" = "allow";
      "which" = "allow";
      "which *" = "allow";
      "whereis" = "allow";
      "whereis *" = "allow";
      # Not "type*" — that matched typeprof, a Ruby analyser that loads code.
      "type" = "allow";
      "type *" = "allow";

      # -- Text processing (read-only)
      "echo" = "allow";
      "echo *" = "allow";
      # sed: allow the read-only forms (-n, -E, s///, /d — all print to stdout)
      # and pull back only the ones that write or execute. Longer patterns win
      # (rules sort by length, last match wins), so these override "sed *".
      #   -i / --in-place → edits files in place ("--in-place" contains "-i")
      #   s///w file      → writes a file
      #   s///e           → executes the result as a shell command
      "sed" = "allow";
      "sed *" = "allow";
      "sed*-i*" = "ask";
      "sed*/w *" = "ask";
      "sed*/e *" = "ask";
      "sed*/e'*" = "ask";
      "sed*/e\"*" = "ask";
      "uniq" = "allow";
      "uniq *" = "allow";
      "diff" = "allow";
      "diff *" = "allow";
      "comm" = "allow";
      "comm *" = "allow";
      "cut" = "allow";
      "cut *" = "allow";
      # Not "tr*": that matched `truncate`, which zeroes a file with no root.
      "tr" = "allow";
      "tr *" = "allow";
      "jq" = "allow";
      "jq *" = "allow";
      "yq" = "allow";
      "yq *" = "allow";
      "column" = "allow";
      "column *" = "allow";
      "tac" = "allow";
      "tac *" = "allow";
      "rev" = "allow";
      "rev *" = "allow";
      "paste" = "allow";
      "paste *" = "allow";
      "expand" = "allow";
      "expand *" = "allow";
      "unexpand" = "allow";
      "unexpand *" = "allow";
      "fold" = "allow";
      "fold *" = "allow";
      "fmt" = "allow";
      "fmt *" = "allow";
      "nl" = "allow";
      "nl *" = "allow";

      # -- System info
      # Every entry here is exact-plus-args rather than a bare prefix glob.
      # A "cmd*" glob silently captures every binary whose name starts with
      # cmd, and on this machine that included `uname26` (runs any command
      # under a faked uname), `idle3` (runs arbitrary Python via -r),
      # `hostnamectl`, `identify` and `localectl`.
      "uname" = "allow";
      "uname *" = "allow";
      "hostname" = "allow";
      "hostname *" = "allow";
      "whoami" = "allow";
      "whoami *" = "allow";
      "id" = "allow";
      "id *" = "allow";
      "printenv" = "allow";
      "printenv *" = "allow";
      "date" = "allow";
      "date *" = "allow";
      "uptime" = "allow";
      "uptime *" = "allow";
      "pwd" = "allow";
      "pwd *" = "allow";
      "locale" = "allow";
      "locale *" = "allow";
      "getconf" = "allow";
      "getconf *" = "allow";

      # -- Process inspection
      # Exact + args rather than "ps*": that glob also matched `psql`, i.e. a
      # shell for every database this machine is configured against.
      "ps" = "allow";
      "ps *" = "allow";
      "pgrep" = "allow";
      "pgrep *" = "allow";

      # -- Network (read-only)
      "curl" = "allow";
      "curl *" = "allow";
      "dig" = "allow";
      "dig *" = "allow";
      "nslookup" = "allow";
      "nslookup *" = "allow";
      "ping" = "allow";
      "ping *" = "allow";
      # Not "host*", which matched any binary starting with "host".
      "host" = "allow";
      "host *" = "allow";

      # -- Cargo / Rust
      "cargo check*" = "allow";
      "cargo test*" = "allow";
      "cargo clippy*" = "allow";
      "cargo build*" = "allow";
      "cargo doc*" = "allow";
      "cargo fmt --check*" = "allow";
      "cargo tree*" = "allow";
      "cargo metadata*" = "allow";
      "cargo pkgid*" = "allow";
      "cargo verify-project*" = "allow";
      "cargo bench*" = "allow";
      "rustc --version*" = "allow";
      "rustc --explain*" = "allow";
      "rustup show*" = "allow";
      "rustup target list*" = "allow";
      "rustup toolchain list*" = "allow";
      "*=* cargo *" = "allow";
      "*=* rustc *" = "allow";
      "timeout * cargo *" = "allow";
      "timeout * rustc *" = "allow";
      "*=* timeout * cargo *" = "allow";

      # -- Node / JS
      "node --version*" = "allow";
      "npm list*" = "allow";
      "npm info*" = "allow";
      "npm view*" = "allow";
      "npm ls*" = "allow";
      "npm outdated*" = "allow";
      "npm audit*" = "allow";
      "npm explain*" = "allow";
      "pnpm list*" = "allow";
      "pnpm info*" = "allow";
      "pnpm outdated*" = "allow";
      "pnpm audit*" = "allow";
      "npx --version*" = "allow";

      # -- Python
      "python3 --version*" = "allow";

      # -- Just
      "just --list*" = "allow";
      "just --summary*" = "allow";
      "just --show*" = "allow";
      "just --evaluate*" = "allow";
      "just --dump*" = "allow";

      # -- GH CLI (read-only, supplements custom tools)
      "gh issue list*" = "allow";
      "gh issue view*" = "allow";
      "gh issue status*" = "allow";
      "gh pr list*" = "allow";
      "gh pr view*" = "allow";
      "gh pr diff*" = "allow";
      "gh pr checks*" = "allow";
      "gh pr status*" = "allow";
      "gh repo view*" = "allow";
      "gh repo list*" = "allow";
      "gh run list*" = "allow";
      "gh run view*" = "allow";
      "gh run watch*" = "allow";
      "gh workflow list*" = "allow";
      "gh workflow view*" = "allow";
      "gh search *" = "allow";
      "gh status*" = "allow";
      "gh auth status*" = "allow";

      # -- Herdr: inspection + topology
      "herdr status*" = "allow";
      "herdr --version*" = "allow";
      "herdr session list*" = "allow";
      "herdr workspace list*" = "allow";
      "herdr workspace get*" = "allow";
      "herdr workspace create*" = "allow";
      "herdr workspace focus*" = "allow";
      "herdr tab list*" = "allow";
      "herdr tab create*" = "allow";
      "herdr tab focus*" = "allow";
      "herdr pane list*" = "allow";
      "herdr pane get*" = "allow";
      "herdr pane current*" = "allow";
      "herdr pane layout*" = "allow";
      "herdr pane process-info*" = "allow";
      "herdr pane neighbor*" = "allow";
      "herdr pane edges*" = "allow";
      "herdr pane read*" = "allow";
      "herdr pane wait-output*" = "allow";
      "herdr pane split*" = "allow";
      "herdr pane focus*" = "allow";
      "herdr pane zoom*" = "allow";
      "herdr pane rename*" = "allow";
      "herdr pane resize*" = "allow";
      "herdr agent list*" = "allow";
      "herdr agent get*" = "allow";
      "herdr agent read*" = "allow";
      "herdr agent wait*" = "allow";
      "herdr agent focus*" = "allow";
      "herdr agent rename*" = "allow";
      "herdr agent start*" = "ask";
      "herdr agent prompt*" = "ask";
      "herdr integration status*" = "allow";
      "herdr plugin list*" = "allow";
      "herdr notification show*" = "allow";
    };
in rec {
  inherit baseBash;
  ghCustomTools = {
    gh_issue_read = "allow";
    gh_issue_write = "ask";
    gh_pr_read = "allow";
    gh_pr_write = "ask";
    gh_workflow_read = "allow";
    gh_workflow_write = "ask";
    gh_run_read = "allow";
    gh_run_write = "ask";
    gh_search = "allow";
    gh_status = "allow";
    gh_repo_read = "allow";
    gh_repo_write = "ask";
    google_calendar = "allow";
    date = "allow";
  };

  ghCustomToolsReadOnly =
    ghCustomTools
    // {
      gh_issue_write = "deny";
      gh_pr_write = "deny";
      gh_workflow_write = "deny";
      gh_run_write = "deny";
      gh_repo_write = "deny";
    };

  denyDatadog = {"datadog_*" = "deny";};

  denyTicketWrites = {
    "linear_save_*" = "deny";
    "linear_create_*" = "deny";
    "linear_delete_*" = "deny";
    "linear_prepare_attachment_upload" = "deny";
    "Notion_notion-create-*" = "deny";
    "Notion_notion-update-*" = "deny";
    "Notion_notion-move-pages" = "deny";
    "Notion_notion-duplicate-page" = "deny";
  };

  sharedBase = {
    external_directory = {
      "/nix/store/**" = "allow";
      "~/granted/**" = "allow";
      "/tmp/**" = "allow";
    };
    question = "allow";

    host_exec = "ask";
    host_mount = "ask";
    host_journal = "ask";
  };

  primaryBase =
    {
      bash = baseBash;
    }
    // sharedBase
    // ghCustomTools
    // denyDatadog
    // denyTicketWrites;
}
