# Caveman as an omp extension package, rebuilt from the pinned upstream source.
#
# Reproduces installer/install.js `writeOmpPluginPackage` instead of running
# `omp plugin install`, which would symlink a mutable ~/.omp/caveman-plugin
# into ~/.omp/plugins and write a lockfile. The result is listed in
# `extensions:`, which wires the sibling skills/ commands/ agents/ rules/ the
# same way the plugin manager would.
#
# The installer's omp code is hashed so `nix flake update caveman` fails the
# build when upstream changes what it deploys.
{
  pkgs,
  lib,
  caveman,
}: let
  installerHash = "46ad8d6d5251280229d6060656d4b431e9d423476a06a4589999d94c3311e9a3";

  installerCheck = pkgs.runCommand "caveman-omp-installer-check" {} ''
    {
      grep -E '^const (OMP_|OPENCODE_(SKILL_DIRS|AGENT_FILES|COMMAND_FILES))' ${caveman}/installer/install.js
      for fn in installOmp writeOmpPluginPackage ompExtensionSource; do
        # Whole function body: stop at the next top-level function.
        awk -v fn="$fn" '$0 ~ "^function " fn "\\(" {f=1; print; next}
                         f && /^function [a-zA-Z]/{exit} f' ${caveman}/installer/install.js
      done
      cat ${caveman}/installer/lib/opencode-agent.js
    } | sha256sum | cut -d' ' -f1 > $out

    actual=$(cat $out)
    if [ "$actual" != "${installerHash}" ]; then
      echo ""
      echo "ERROR: caveman's omp installer has changed."
      echo "  expected: ${installerHash}"
      echo "  got:      $actual"
      echo ""
      echo "Review installOmp / writeOmpPluginPackage / ompExtensionSource in"
      echo "installer/install.js, update modules/programs/omp/_caveman.nix, then"
      echo "set installerHash to the new value."
      exit 1
    fi
  '';

  skillDirs = ["caveman" "ultracave" "megacave" "caveman-commit" "caveman-review" "caveman-help" "caveman-stats" "caveman-compress" "cavecrew"];
  agentFiles = ["cavecrew-investigator.md" "cavecrew-builder.md" "cavecrew-reviewer.md"];
  commandFiles = ["caveman.md" "ultracave.md" "megacave.md" "caveman-commit.md" "caveman-review.md" "caveman-compress.md" "caveman-stats.md" "caveman-help.md"];

  rule = builtins.readFile "${caveman}/src/rules/caveman-activate.md";

  # Same source as ompExtensionSource: the rule is embedded, and re-appended
  # on every before_agent_start so the mode survives past the first prompt.
  # Except the status: upstream's screaming `CAVEMAN` is replaced by an icon
  # plus a muted label, matching ponytail's stamp.
  index = pkgs.writeText "index.cjs" ''
    'use strict';

    const STATUS_LABEL = 'caveman';
    const RULE = ${builtins.toJSON rule};

    module.exports = function cavemanPlugin(pi) {
      if (!pi || typeof pi.on !== 'function') return;
      pi.on('session_start', async (_event, ctx) => {
        if (ctx && ctx.ui && typeof ctx.ui.setStatus === 'function') {
          let label = 'caveman';
          try {
            const theme = ctx.ui.theme;
            if (theme && typeof theme.fg === 'function') label = theme.fg('muted', label);
          } catch (_) {}
          ctx.ui.setStatus(STATUS_LABEL, '🪨 ' + label);
        }
      });
      pi.on('before_agent_start', async (event) => {
        const base = event && Array.isArray(event.systemPrompt) ? event.systemPrompt : [];
        const entry = 'CAVEMAN MODE ACTIVE - session ruleset applies.' + String.fromCharCode(10, 10) + RULE;
        if (base.indexOf(entry) !== -1) return undefined;
        return { systemPrompt: base.concat([entry]) };
      });
    };
  '';

  packageJson = pkgs.writeText "package.json" (builtins.toJSON {
    name = "caveman";
    version = (lib.importJSON "${caveman}/package.json").version;
    description = "Caveman terse communication mode for Oh My Pi";
    omp = {
      description = "Caveman terse communication mode for Oh My Pi";
      extensions = ["./index.cjs"];
    };
  });
in
  pkgs.runCommand "caveman-omp" {inherit installerCheck;} ''
    mkdir -p $out/skills $out/commands $out/agents $out/rules
    cp ${packageJson} $out/package.json
    # .cjs: omp transpiles .js as ESM, and module.exports must load as a factory.
    cp ${index} $out/index.cjs

    ${lib.concatMapStrings (d: "cp -r ${caveman}/skills/${d} $out/skills/${d}\n") skillDirs}
    ${lib.concatMapStrings (f: "cp ${caveman}/src/plugins/opencode/commands/${f} $out/commands/${f}\n") commandFiles}
    cp ${caveman}/src/rules/caveman-activate.md $out/rules/caveman.md

    # transformOpencodeAgentFrontmatter without { subagent: true }: drop
    # `tools:` (block or inline) and provider-less `model:` values.
    for f in ${lib.concatStringsSep " " agentFiles}; do
      ${pkgs.gawk}/bin/awk '
        BEGIN { in_fm = 0; seen = 0; dropping = 0 }
        /^---$/ && seen < 2 { seen++; in_fm = (seen == 1); dropping = 0; print; next }
        in_fm && dropping && /^[^ \t]/ { dropping = 0 }
        in_fm && dropping { next }
        in_fm && /^tools[ \t]*:/ { dropping = 1; next }
        in_fm && /^model[ \t]*:/ {
          val = $0; sub(/^model[ \t]*:[ \t]*/, "", val)
          gsub(/[ \t]*#.*$/, "", val); gsub(/^["'"'"']|["'"'"']$/, "", val)
          if (val != "" && index(val, "/") == 0) next
        }
        { print }
      ' ${caveman}/agents/"$f" > $out/agents/"$f"
    done
  ''
