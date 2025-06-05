{ config, pkgs, lib, ...}:
with lib;

let
  cfgs = config.services.gitDirSync;

in
{
  options.services.gitDirSync = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption "enable dir sync service";

        repoUrl = mkOption {
          type = types.str;
          example = "https://github.com/nix-freifunk/fastd-keys.git";
          description = "The repo that should be synced.";
        };

        repoBranch = mkOption {
          type = types.str;
          default = "main";
          description = "The repo branch that should be synced.";
        };

        syncDir = mkOption {
          type = types.path;
          example = "/var/lib/fastd/peer_groups/nodes";
          description = "The path to where the dir should be stored.";
        };

        reloadServices = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "The services that should be reloaded if something changed.";
        };

        timer = {
          enable = mkEnableOption "enable timer for automatic syncing";

          onCalendar = mkOption {
            type = types.str;
            default = "*-*-* *:0/5:00";
            description = "The intervall in which the sync should be run. Default is every 5 minutes.";
          };
          randomizedDelaySec = mkOption {
            type = types.str;
            default = "4m";
            description = "Add a random delay to the timer.";
          };
          fixedRandomDelay = mkOption {
            type = types.bool;
            default = true;
            description = "Add a random delay to the timer.";
          };
        };

        extraCommandsOnSetup = mkOption {
          type = types.lines;
          default = "";
          description = "Command to run on when setting up dir. Can be used to fill it up until there is a sync.";
        };

        extraCommandsOnChange = mkOption {
          type = types.lines;
          default = "";
          description = "Commands to run on if there have been changes.";
        };

        unitName = mkOption {
          type = types.str;
          default = "git-dir-sync-${name}";
          readOnly = true;
          description = "The name of the periodic reload service.";
        };

        unitNameSetup = mkOption {
          type = types.str;
          default = "git-dir-sync-${name}-setup";
          readOnly = true;
          description = "The name of the service to conditionally create the sync dir.";
        };

        sshCommand = mkOption {
          type = types.str;
          default = "${pkgs.openssh}/bin/ssh";
          description = "The ssh command to use";
        };
      };
    }));
    default = {};
    description = "Setup git directory sync services.";
  };

  config = mkIf (cfgs != {}) {
    systemd.services = mkMerge ( lib.mapAttrsToList (name: cfg: lib.mkIf cfg.enable (lib.listToAttrs [
      (lib.nameValuePair cfg.unitNameSetup {
        serviceConfig.Type = "oneshot";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        script = ''
          set -x

          export GIT_COMMITTER_NAME="system"
          export GIT_COMMITTER_EMAIL="info@example.org"
          export GIT_SSH_COMMAND="${cfg.sshCommand}"

          SYNC_DIR="${cfg.syncDir}"

          BIN_MKDIR=("${pkgs.coreutils}/bin/mkdir")
          BIN_GIT=("${pkgs.git}/bin/git -C $SYNC_DIR")

          if [ ! -d "$SYNC_DIR" ]; then
            $BIN_MKDIR --parents $SYNC_DIR
            $BIN_GIT init --initial-branch=${cfg.repoBranch}

            $BIN_GIT commit --allow-empty -m "init" --author "$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>"

            $BIN_GIT remote add origin ${cfg.repoUrl}
            $BIN_GIT fetch origin
            # $BIN_GIT checkout ${cfg.repoBranch}
            $BIN_GIT branch --set-upstream-to=origin/${cfg.repoBranch} ${cfg.repoBranch}
            # $BIN_GIT checkout -b ${cfg.repoBranch} --track origin/${cfg.repoBranch}

            ${cfg.extraCommandsOnSetup}
          fi
        '';
      })
      (nameValuePair cfg.unitName {
        serviceConfig.Type = "oneshot";
        after = [ "network-online.target" /*"${cfg.unitNameSetup}.service"*/ ];
        wants = [ "network-online.target" /*"${cfg.unitNameSetup}.service"*/ ];
        script = ''
          set -x

          export GIT_SSH_COMMAND="${cfg.sshCommand}"

          BIN_GIT=("${pkgs.git}/bin/git -C ${cfg.syncDir}")
          BIN_SYSTEMCTL=("${pkgs.systemd}/bin/systemctl")
          BIN_ECHO=("${pkgs.coreutils}/bin/echo")

          HEAD_PRE=$($BIN_GIT rev-parse HEAD || echo 0)

          $BIN_GIT remote set-url origin ${cfg.repoUrl}
          $BIN_GIT fetch origin --prune

          $BIN_GIT branch --move --force ${cfg.repoBranch}
          $BIN_GIT branch --set-upstream-to=origin/${cfg.repoBranch}
          $BIN_GIT reset --hard origin/${cfg.repoBranch} --

          HEAD_POST=$($BIN_GIT rev-parse HEAD)

          if [ "$HEAD_PRE" != "$HEAD_POST" ]; then
            $BIN_ECHO "changes detected"
            ${concatMapStringsSep "\n  " (service: "$BIN_SYSTEMCTL is-active --quiet ${service} && $BIN_SYSTEMCTL reload ${service}") cfg.reloadServices}

            ${cfg.extraCommandsOnChange}
          fi

          exit 0
        '';
      })
    ])) cfgs);

    systemd.timers = mkMerge (lib.mapAttrsToList (name: cfg:
        lib.mkIf cfg.timer.enable (lib.listToAttrs [
          (lib.nameValuePair cfg.unitName {
            wantedBy = [ "timers.target" ];
            partOf = [ "${cfg.unitName}.service" ];
            timerConfig = {
              OnCalendar = [ cfg.timer.onCalendar ];
              RandomizedDelaySec = cfg.timer.randomizedDelaySec;
              FixedRandomDelay = cfg.timer.fixedRandomDelay;
            };
          })
        ])
      ) cfgs
    );
  };
}
