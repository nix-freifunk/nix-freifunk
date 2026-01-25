{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2026-01-15";

  src = fetchFromGitHub {
    owner = "freifunk-gluon";
    repo = "gluon-firmware-selector";
    rev = "03e3f4172f9dd7d7c60ed1934688cfd4941e009d";
    sha256 = "sha256-y7u3k8MVB/8KDIt9ibq0HOoF0RNXuUKTlOvxjxoLYfI=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
    echo "VERSION=${version}" > $out/version.txt
    echo "REV=${src.rev}" >> $out/version.txt
  '';
}
