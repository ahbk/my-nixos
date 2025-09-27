{ inputs, pkgs, ... }:
{
  config =
    let
      km-tools = pkgs.stdenv.mkDerivation {
        pname = "km-tools";
        version = "0.1.0";
        src = ../tools;

        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.shellcheck
        ];

        doCheck = true;

        checkPhase = ''
          runHook preCheck

          echo "Running shellcheck on all scripts..."
          find bin libexec -type f -print0 | xargs -0 shellcheck

          runHook postCheck
        '';

        installPhase = ''
          runHook preInstall
          install -d $out/bin $out/libexec $out/share/doc

          install -m 755 bin/* $out/bin/
          install -m 644 libexec/* $out/libexec/
          install -m 644 share/doc/* $out/share/doc/
          cp .shellcheckrc $out/

          patchShebangs $out/bin/*

          for script in $out/bin/*; do
            wrapProgram "$script" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath (
                  with pkgs;
                  [
                    sops
                    age
                    openssl
                    openssh
                    wireguard-tools
                    jq
                    yq-go
                  ]
                )
              } \
              --set REPO_ROOT "${inputs.self}" \
              --set LOG_LEVEL info
            done

            runHook postInstall
        '';
      };
    in
    {
      environment.systemPackages = [ km-tools ];
    };
}
