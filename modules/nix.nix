{
  config,
  ids,
  inputs,
  lib,
  pkgs,
  host,
  ...
}:

let
  inherit (lib) mkDefault mkForce;
  cfg = config.my-nixos.nix;

  nixservicePkg =
    pkgs.runCommand "nixservice"
      {
        buildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        cp ${../tools/nixservice.sh} $out/bin/nixservice-unwrapped
        chmod +x $out/bin/nixservice-unwrapped

        makeWrapper $out/bin/nixservice-unwrapped $out/bin/nixservice \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.lix
            ]
          } \
          --set REPO "${cfg.repo}"
      '';
in
{
  options.my-nixos.nix = {
    repo = lib.mkOption {
      description = "repo for this config";
      type = lib.types.str;
      default = "github:ahbk/my-nixos/add-host-helsinki";
    };
  };
  config = {
    nix = {
      package = mkDefault pkgs.lix;
      registry = {
        self.flake = inputs.self;
        my-nixos = {
          from = {
            id = "my-nixos";
            type = "indirect";
          };
          to = {
            owner = "ahbk";
            repo = "my-nixos";
            type = "github";
          };
        };
        nixpkgs.flake = inputs.nixpkgs;
      };
      channel.enable = false;
      settings = {
        auto-optimise-store = false;
        bash-prompt-prefix = "(nix:$name)\\040";
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        max-jobs = "auto";
        nix-path = mkForce "nixpkgs=/etc/nix/inputs/nixpkgs";
        substituters = [
          "https://cache.nixos.org"
          "https://cache.lix.systems"
        ];
        trusted-users = [ "@wheel" ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
        ];
        use-xdg-base-directories = true;
      };
    };
    environment.etc = {
      "nix/inputs/self".source = "${inputs.self}";
      "nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";
    };

    services.nix-serve = {
      enable = true;
      bindAddress = "0.0.0.0";
    };

    users.users.nixbuilder = {
      isSystemUser = true;
      shell = pkgs.bash;
      home = "/var/lib/nixbuilder";
      createHome = true;

      openssh.authorizedKeys.keyFiles = [
        ../public-keys/service-nixbuilder-ssh-key.pub
      ];
      uid = ids.nixbuilder.uid;
      group = "nixbuilder";
    };

    users.groups.nixbuilder = {
      gid = ids.nixbuilder.uid;
    };

    users.users.nixswitcher = {
      isSystemUser = true;
      shell = pkgs.bash;

      openssh.authorizedKeys.keyFiles = [
        ../public-keys/service-nixswitcher-ssh-key.pub
      ];
      uid = ids.nixswitcher.uid;
      group = "nixswitcher";
    };

    users.groups.nixswitcher = {
      gid = ids.nixswitcher.uid;
    };

    services.openssh = {
      extraConfig = ''
        Match User nixbuilder
          ForceCommand ${nixservicePkg}/bin/nixservice \$SSH_ORIGINAL_COMMAND

        Match User nixswitcher
          ForceCommand sudo ${nixservicePkg}/bin/nixservice switch \$SSH_ORIGINAL_COMMAND
      '';
    };

    security.sudo.extraRules = [
      {
        users = [ "nixservice" ];
        commands = [
          {
            command = "${nixservicePkg}/bin/nixservice switch *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

  };
}
