{ stdenv, fetchurl, unzip }:

stdenv.mkDerivation rec {
  pname = "meshviewer";
  version = "12.5.0";

  src = fetchurl {
    url = "https://github.com/freifunk/meshviewer/releases/download/v${version}/meshviewer-build.zip";
    sha256 = "sha256-b5/aMtckvH4sHNCqxdR98ZpknNEtXx+0HFOlxgKXKmE=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  buildPhase = ''
    mkdir -p $out
    cp -r * $out
  '';
}
