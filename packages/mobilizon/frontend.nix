{
  lib,
  buildNpmPackage,
  imagemagick,
  mobilizon-src,
}:

buildNpmPackage {
  pname = "mobilizon";
  version = "5.1.1";
  src = mobilizon-src;

  npmDepsHash = "sha256-oOV4clyUzKTdAMCKghWS10X9Nug9j8mil/vXcFhZ6Z0=";

  nativeBuildInputs = [ imagemagick ];

  postInstall = ''
    cp -r priv/static $out/static
  '';

  meta = with lib; {
    description = "Frontend for the Mobilizon server";
    homepage = "https://joinmobilizon.org/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [
      minijackson
      erictapen
    ];
  };
}
