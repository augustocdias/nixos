{den, ...}: {
  den.aspects.work = {
    includes = with den.aspects; [
      podman
      virtualization
      teamviewer
      lotion
      datagrip
      slack
      wireguard
      jgrep
      claude-code
      claude-code-jail
    ];

    homeManager = {
      pkgs,
      lib,
      config,
      ...
    }: let
      shared = import ../../programs/agent-shared/_lib.nix {inherit lib;};
      agents = ../../programs/claude-code/agents;
      readOnlyAgent = name: description: preamble:
        pkgs.writeText "${name}.md" (shared.withFrontmatterText {
            inherit name description;
            tools = config.omp.readOnlyTools;
          }
          (preamble + builtins.readFile "${agents}/${name}.md"));

      # omp subagents run headless, and omp's gate.ts blocks every work-MCP
      # write without a UI, so the approval has to happen in the parent.
      ticketsPreamble = ''
        **Writes are not available to you.** You run as a headless subagent:
        every Linear/Notion write tool call is blocked, even after the user
        approved it in the parent conversation. Do all reads and drafting
        yourself, then end with each mutation as a proposal — the exact tool
        name and its full arguments — for the parent session to perform. The
        approval prompt happens there. Never retry a blocked write.

      '';
    in {
      home.packages = with pkgs; [
        just
        awscli2
      ];

      # Work MCPs for omp. OAuth runs in-app (`/mcp reauth <name>`); tokens land
      # in ~/.omp/agent/agent.db. Writes are gated by omp's extensions/gate.ts.
      omp.mcpServers = {
        notion = {
          type = "http";
          url = "https://mcp.notion.com/mcp";
        };
        linear = {
          type = "http";
          url = "https://mcp.linear.app/mcp";
        };
        datadog = {
          type = "http";
          url = "https://mcp.datadoghq.eu/v1/mcp";
        };
      };

      home.file = {
        ".omp/agent/agents/troubleshoot.md".source = readOnlyAgent "troubleshoot" "Investigates production issues and incidents using Datadog (logs, traces, metrics, RUM, monitors, incidents). Use for \"why is X slow/erroring\", incident triage, latency/error spikes, log/trace analysis, or metric investigation." "";
        ".omp/agent/agents/tickets.md".source = readOnlyAgent "tickets" "Manages Linear issues and Notion docs — triage, spec writing, status updates, ticket creation, and cross-referencing docs. Writes are approval-gated. Use for ticket workflow, writing/updating specs, or pulling context out of Notion/Linear." ticketsPreamble;
        ".omp/agent/skills/datadog-queries".source = ../../programs/claude-code/skills/datadog-queries;
      };
    };
  };
}
