{
  stdenv,
  makeWrapper,
  shellcheck,
  lib,
  sops,
  age,
  openssl,
  openssh,
  wireguard-tools,
  jq,
  yq-go,
  nix-serve-ng,
  inputs,
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
            sops
            age
            openssl
            openssh
            wireguard-tools
            jq
            yq-go
            nix-serve-ng
          ]
        }
    done
    runHook postInstall
  '';
}
