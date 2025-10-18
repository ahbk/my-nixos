{
  age,
  inputs,
  jq,
  lib,
  makeWrapper,
  openssh,
  openssl,
  shellcheck,
  sops,
  stdenv,
  toml2json,
  wireguard-tools,
  ...
}:

stdenv.mkDerivation {
  pname = "km-tools";
  version = "0.1.0";
  src = "${inputs.self}/tools";

  nativeBuildInputs = [
    makeWrapper
    shellcheck
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    find bin libexec -type f -print0 | xargs -0 shellcheck
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a ./ $out

    patchShebangs $out/bin $out/libexec

    for script in $out/bin/*; do
      wrapProgram "$script" \
        --set REPO_ROOT ${inputs.self} \
        --prefix PATH : ${
          lib.makeBinPath [
            age
            jq
            openssl
            openssh
            sops
            toml2json
            wireguard-tools
          ]
        }
    done
    runHook postInstall
  '';
}
