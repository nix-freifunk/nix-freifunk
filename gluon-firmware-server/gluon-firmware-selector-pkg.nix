{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2025-07-31";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "91dfdb813cb08bfaaf62eb90ad2a61386d95cdbd";
    sha256 = "sha256-9+mwaNq/M8wIrwUydQVIunZzledF+wTPJrwYOCf881s=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
    echo "VERSION=${version}" > $out/version.txt
    echo "REV=${src.rev}" >> $out/version.txt
  '';
}
