{den, ...}: {
  den.aspects.git = {
    homeManager = _: {
      programs.git = {
        enable = true;
        lfs.enable = true;

        signing = {
          key = "7D8396F74725A208D835CE3730E62A1E4F078650";
          signByDefault = true;
        };

        settings = {
          user = {
            name = "Augusto César Dias";
            email = "augusto.c.dias@gmail.com";
          };

          alias = {
            a = "add";
            aa = "add .";
            ap = "add -p";
            b = "branch";
            brm = "branch -D";
            s = "status -s";
            st = "status";
            sl = "stash list";
            sa = "stash apply";
            ss = "stash save";
            co = "checkout";
            cob = "checkout -b";
            c = "commit";
            cm = "commit -m";
            cam = "commit -am";
            diff-sbs = "-c delta.features=side-by-side diff";
            wls = "worktree list";
            wrm = "worktree remove";
            wa = ''              !f() { \
                            local common project path; \
                            common=$(git rev-parse --path-format=absolute --git-common-dir) || return 1; \
                            project=$(dirname "$(dirname "$common")"); \
                            path="$project/$1"; \
                            git worktree add "$path" -b "$1"; \
                          }; f'';
            ls = ''log --pretty=format:"%C(yellow)%h%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate'';
            ll = ''log --pretty=format:"%C(yellow)%h%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate --numstat'';
            lds = ''log --pretty=format:"%C(yellow)%h\ %ad%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate --date=short'';
            ld = ''log --pretty=format:"%C(yellow)%h\ %ad%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate --date=relative'';
            filelog = "log -u";
            dl = "!git ll -1";
            dlc = "-c delta.features=side-by-side diff --cached HEAD^";
            grep = "grep -Ii";
            la = "!git config -l | grep alias | cut -c 7-";
            tidy = "remote prune origin";
            t = "stash";
            tp = "stash pop";
            tl = "stash list";
            sr = "rebase --update-refs --onto main";
          };

          core.editor = "nvim --cmd 'let g:unception_block_while_host_edits=1'";
          pull.rebase = true;
          rebase = {
            autosquash = true;
            updateRefs = true;
          };
          diff.tool = "diffview";
          difftool.prompt = false;
          "difftool \"diffview\"".cmd = ''nvim -n -c "DiffviewOpen" "$MERGE"'';
          merge = {
            tool = "diffview";
            conflictstyle = "zdiff3";
          };
          mergetool = {
            keepBackup = false;
            trustExitCode = false;
            prompt = true;
          };
          "mergetool \"diffview\"".cmd = ''nvim -n -c "DiffviewOpen" "$MERGE"'';
          init.defaultBranch = "main";
        };
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          navigate = true;
          true-color = "always";
          side-by-side = false;
          interactive.diff-filter = "delta -s";
          features = "catppuccin-mocha";
        };
      };

      xdg.configFile."delta/catppuccin.gitconfig".source = ./catppuccin.gitconfig;
    };
  };
}
