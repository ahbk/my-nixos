{
  config,
  ids,
  inputs,
  lib,
  pkgs,
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
        cp ${../tools/remote/nixservice.sh} $out/bin/nixservice-unwrapped
        chmod +x $out/bin/nixservice-unwrapped

        makeWrapper $out/bin/nixservice-unwrapped $out/bin/nixservice \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.lix
              pkgs.git
            ]
          } \
          --set REPO "${cfg.repo}" \
          --set BUILD_HOST "${cfg.buildHost}"
      '';
in
{
  options.my-nixos.nix = {
    serveStore = lib.mkEnableOption "nix-serve on this host";
    repo = lib.mkOption {
      description = "repo for this config";
      type = lib.types.str;
      default = "github:ahbk/my-nixos";
    };
    buildHost = lib.mkOption {
      description = "default BUILD_HOST";
      type = lib.types.str;
      default = "stationary.km";
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.serveStore {
      sops.secrets.nix-cache-key = { };
      services.nix-serve = {
        enable = true;
        bindAddress = "0.0.0.0";
        secretKeyFile = config.sops.secrets.nix-cache-key.path;
      };
    })
    {
      programs.ssh.knownHosts.github = {
        hostNames = [ "github.com" ];
        publicKeyFile = ../public-keys/ext-github-ssh-key.pub;
      };

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
          trusted-users = [
            "@wheel"
            "nix-push"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
            (builtins.readFile ../public-keys/host-stationary-nix-cache-key.pub)
          ];
          use-xdg-base-directories = true;
        };
      };
      environment.etc = {
        "nix/inputs/self".source = "${inputs.self}";
        "nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";
      };

      users.users.nix-build = {
        isSystemUser = true;
        shell = pkgs.bash;
        home = "/var/lib/nix-build";
        createHome = true;

        openssh.authorizedKeys.keyFiles = [
          ../public-keys/service-nix-build-ssh-key.pub
        ];
        uid = ids.nix-build.uid;
        group = "nix-build";
      };

      users.groups.nix-build = {
        gid = ids.nix-build.uid;
      };

      users.users.nix-switch = {
        isSystemUser = true;
        shell = pkgs.bash;

        openssh.authorizedKeys.keyFiles = [
          ../public-keys/service-nix-switch-ssh-key.pub
        ];
        uid = ids.nix-switch.uid;
        group = "nix-switch";
      };

      users.groups.nix-switch = {
        gid = ids.nix-switch.uid;
      };

      users.users.nix-push = {
        isSystemUser = true;
        shell = pkgs.bash;

        openssh.authorizedKeys.keyFiles = [
          ../public-keys/service-nix-push-ssh-key.pub
        ];
        uid = ids.nix-push.uid;
        group = "nix-push";
      };

      users.groups.nix-push = {
        gid = ids.nix-push.uid;
      };

      services.openssh = {
        extraConfig = ''
          Match User nix-build
            ForceCommand ${nixservicePkg}/bin/nixservice \$SSH_ORIGINAL_COMMAND

          Match User nix-switch
            ForceCommand sudo ${nixservicePkg}/bin/nixservice switch \$SSH_ORIGINAL_COMMAND

          Match User nix-push
            ForceCommand ${pkgs.nix}/bin/nix-store --serve --write
        '';
      };

      security.sudo.extraRules = [
        {
          users = [ "nix-switch" ];
          commands = [
            {
              command = "${nixservicePkg}/bin/nixservice switch *";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

    }
  ];
}
