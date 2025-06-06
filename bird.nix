{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.freifunk.bird;
in
{
  options.services.freifunk.bird = {
    enable = lib.mkEnableOption "Enable Bird";
    extraTables = lib.mkOption {
      type = types.lines;
      default = "";
    };
    extraVariables = lib.mkOption {
      type = types.lines;
      default = "";
    };
    extraFunctions = lib.mkOption {
      type = types.lines;
      default = "";
    };
    extraFilters = lib.mkOption {
      type = types.lines;
      default = "";
    };
    extraTemplates = lib.mkOption {
      type = types.lines;
      default = "";
    };
    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
    };
    routerId = lib.mkOption {
      type = types.str;
    };
    localAdresses = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    systemd.network = {
      netdevs = {
        "10-dummy0" = {
          netdevConfig = {
            Name = "dummy0";
            Kind = "dummy";
          };
        };

      };
      networks = {
        "10-dummy0" = {
          matchConfig = {
            Name = "dummy0";
          };
          networkConfig = {
            Address = cfg.localAdresses;
            LinkLocalAddressing = "no";
          };
          linkConfig = {
            RequiredForOnline = false;
          };
        };
      };
    };
    services.bird = {
      enable = true;
      package = pkgs.bird3.overrideAttrs (old: rec {
        version = "3.1.2";
        src = pkgs.fetchFromGitLab {
          domain = "gitlab.nic.cz";
          owner = "labs";
          repo = "bird";
          rev = "v{version}";
          hash = "sha256-3Ms9yozF/Ox/kSP9rzKvkrA0VBPQb1VjtbEInl8/KZM=";
        };
        nativeBuildInputs = old.nativeBuildInputs ++ (with pkgs; [
          autoreconfHook
        ]);
      });
      config = ''
        log syslog all;

        ipv4 table master4;
        ipv6 table master6;

        ${cfg.extraTables}

        router id ${cfg.routerId};

        protocol device {
        }

        define RFC1918 = [
          10.0.0.0/8+,
          172.16.0.0/12+,
          192.168.0.0/16+
        ];

        define RFC4193 = [
          fd00::/8+
        ];

        ${cfg.extraVariables}

        function accept_default_route4() {
          if net = 0.0.0.0/0 then {
            print "Accept (Proto: ", proto, "): ", net, " default route allowed from ", from, " ", bgp_path;
            accept;
          }
        }

        function accept_not_default_route4() {
          if net != 0.0.0.0/0 then {
            accept;
          }
        }

        function accept_default_route6() {
          if net = ::/0 then {
            print "Accept (Proto: ", proto, "): ", net, " default route allowed from ", from, " ", bgp_path;
            accept;
          }
        }

        function accept_not_default_route6() {
          if net != ::/0 then {
            accept;
          }
        }

        ${cfg.extraFunctions}

        ${cfg.extraFilters}

        protocol direct d_dummy0 {
          interface "${config.systemd.network.netdevs."10-dummy0".netdevConfig.Name}";
          ipv4 {
            import filter {
              print "Info (Proto: ", proto, "): ", net, " allowed due to dummy0", bgp_path;
              accept;
            };
          };
          ipv6 {
            import filter {
              print "Info (Proto: ", proto, "): ", net, " allowed due to dummy0 ", bgp_path;
              accept;
            };
          };
        }

        ${cfg.extraTemplates}

        ${cfg.extraConfig}
      '';
    };
  };
}
