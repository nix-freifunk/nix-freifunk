{ lib, config }:
rec {

  intToHex = import ./intToHex.nix { inherit lib; };

  getOnlyEnabled = lib.filterAttrs (_: value: value.enable);

  enabledDomainNames = builtins.attrNames (getOnlyEnabled config.modules.freifunk.gateway.domains);

  getEnabledBatmanInterfaces = domains: map (v: v.batmanAdvanced.interfaceName) (lib.attrValues (lib.filterAttrs (_: v: v.enable && v.batmanAdvanced.enable) domains));

  enabledBatmanInterfaces = getEnabledBatmanInterfaces config.modules.freifunk.gateway.domains;

  enabledBatmanInterfacesNFTstring = lib.concatStringsSep "\", \"" enabledBatmanInterfaces;  
}
