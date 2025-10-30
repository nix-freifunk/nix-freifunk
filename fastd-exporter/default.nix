{ config, lib, pkgs, ... }:

let
  cfg = config.services.fastd-exporter;
  instanceArgs = lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "${name}=${value}") cfg.instances);
in

{

  options.services.fastd-exporter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    instances = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      example = {
        dom0 = "/run/fastd-dom0-vpn.sock";
        dom1 = "/run/fastd-dom1-vpn.sock";
      };
      description = "A mapping of fastd instance names to the unix socket path of the fastd instance.";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 9281;
      description = "The port the exporter should listen on.";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Address to listen on.
      '';
    };
    unitName = lib.mkOption {
      type = lib.types.str;
      default = "fastd-exporter";
      readOnly = true;
      description = "The name of the service.";
    };

    ipASNlookupTimeout = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "milliseconds to wait for ip->asn lookup to finish";
    };
  };

  config = lib.mkIf cfg.enable {

    nixpkgs.overlays = [(self: super: {
      fastd-exporter = self.callPackage ./pkg.nix {};
    })];

    systemd.services.${cfg.unitName} = {
      description = "fastd exporter to allow collecting fastd stats";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.fastd-exporter}/bin/fastd-exporter -web.listen-address ${cfg.listenAddress}:${toString cfg.port} -ip-asn-lookup.timeout ${toString cfg.ipASNlookupTimeout} ${instanceArgs}";
        Restart = "always";
        RestartSec = "30s";
      };
    };
  };
}
