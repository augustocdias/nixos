{den, ...}: {
  den.aspects.gcalcli = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: let
      isLinux = pkgs.stdenv.hostPlatform.isLinux;

      calendar-remind = pkgs.python3Packages.buildPythonApplication {
        pname = "calendar-remind";
        version = "0.1.0";
        format = "other";
        dontUnpack = true;
        propagatedBuildInputs = [pkgs.gcalcli];
        installPhase = ''
          mkdir -p $out/bin
          cp ${./calendar-remind.py} $out/bin/calendar-remind
          chmod +x $out/bin/calendar-remind
        '';
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          "${lib.makeBinPath [pkgs.libnotify pkgs.xdg-utils pkgs.bash]}"
        ];
        meta.mainProgram = "calendar-remind";
      };
    in {
      # On macOS we install gcalcli only — no notification daemon.
      home.packages =
        [pkgs.gcalcli]
        ++ lib.optionals isLinux [calendar-remind];

      systemd.user.services = lib.mkIf isLinux {
        calendar-remind-work = {
          Unit.Description = "Calendar reminder for Work calendar";
          Service = {
            Type = "oneshot";
            ExecStart = "${calendar-remind}/bin/calendar-remind Work";
            KillMode = "process";
          };
        };
      };

      systemd.user.timers = lib.mkIf isLinux {
        calendar-remind-work = {
          Unit.Description = "Check work calendar for upcoming events";
          Timer = {
            OnCalendar = "*:0/5";
            Persistent = false;
          };
          Install.WantedBy = ["timers.target"];
        };
      };
    };
  };
}
