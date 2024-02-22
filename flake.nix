{
  description = "my system";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:ahbk/nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/ahbk/chatddx.com";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib' = import ./lib.nix {
      inherit (nixpkgs) lib;
      inherit pkgs;
    };

    ahbk = {
      user.test = {
        enable = true;
        uid = 1337;
        name = "test";
        email = "test@example.com";
        groups = [ "wheel" ];
        keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
      };

      ide.test = {
        enable = true;
        postgresql = true;
      };

      shell.test.enable = true;

      user.frans = {
        enable = true;
        uid = 1000;
        name = "Alexander Holmbäck";
        email = "alexander.holmback@gmail.com";
        groups = [ "wheel" ];
        keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
      };

      ide.frans = {
        enable = true;
        postgresql = true;
        mysql = true;
      };

      shell.frans.enable = true;
      de.frans.enable = true;

      wordpress.sites."esse.test" = {
        enable = true;
        ssl = false;
      };

      sverigesval = {
        enable = true;
        ssl = false;
        host = "dev.sverigesval.org";
        pkgs = { inherit (inputs.sverigesval.packages.${system}) svelte fastapi; };
        ports = [ 2000 2001 ];
      };

      chatddx = {
        enable = true;
        ssl = true;
        host = "dev.chatddx.com";
        pkgs = { inherit (inputs.chatddx.packages.${system}) svelte django; };
        ports = [ 2002 2003 ];
      };

    };
  in with nixpkgs.lib; {
    homeConfigurations = mapAttrs' (user: cfg: (
      nameValuePair "${user}@seagull" (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs system; };
      modules = [ (import ./modules/all-hm.nix cfg user null) ];
      }))) {
        frans = with ahbk; {
          user.frans = user.frans;
          ide.frans = ide.frans;
          shell.frans = shell.frans;
        };
      };

    nixosConfigurations = rec {

      # nixos@10.233.2.2 for testing
      # nixos-container create test ~/Desktop/nixos
      container = test;
      test = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib' ahbk; };
        modules = with ahbk; [
          ./modules/all.nix
          {
            system.stateVersion = "23.11";
            networking.hostName = "test";
            networking.firewall.enable = false;
            networking.useDHCP = false;
            boot.isContainer = true;
            ahbk = {
              user.frans = user.frans;
              ide.frans = ide.frans;
              shell.frans = shell.frans;
            };
          }
        ];
      };

      friday = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib'; };
        modules = with ahbk; [
          ./hardware/friday.nix
          ./modules/all.nix
          {
            ahbk = {
              user.test = user.test;
              user.frans = user.frans;
              shell.frans = shell.frans;
              ide.frans = ide.frans;
              de.frans = de.frans;
            };

            system.stateVersion = "20.03";
            networking = {
              hostName = "friday";
              nat = {
                enable = true;
                internalInterfaces = ["ve-+"];
                externalInterface = "wlp1s0";
              };
              networkmanager.unmanaged = [ "interface-name:ve-*" ];
            };

            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            programs.light = {
              enable = true;
              brightnessKeys.step = 10;
              brightnessKeys.enable = true;
            };

            services.dnsmasq = {
              enable = true;
              settings.address = "/.test/10.233.2.2";
            };

            # hw quirk: wrong keycode for pipe |
            systemd.services.pipefix = {
              wantedBy = [ "multi-user.target" ];
              after = [ "nix-daemon.socket" ];
              before = [ "systemd-user-sessions.service" ];
              script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
            };
          }
        ];
      };

      glesys = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib'; };
        modules = [
          ./hardware/glesys.nix
          ./modules/all.nix
          {
            networking.hostName = "glesys";
            system.stateVersion = "23.11";

            ahbk = with ahbk; {
              user.frans = user.frans;
              ide.frans = ide.frans;
              shell.frans = shell.frans;

              nginx = {
                enable = true;
                email = user.frans.email;
              };

              inherit chatddx;
            };

            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            swapDevices = [
              {
                device = "/swapfile";
                size = 4096;
              }
            ];
          }
        ];
      };

      jarvis = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system; };
        modules = [
          ./hardware/jarvis.nix
          ./modules/all.nix
          {
            networking.hostName = "jarvis";
            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            ahbk = {
              user.frans = user.frans;
              shell.frans = shell.frans;
            };

            age.secrets."ddns-password".file = ./secrets/ddns-password.age;

            services.networking.inadyn = {
              enable = true;
              providers."default@noip.com" = {
                username = "alexander.holmback@gmail.com";
                hostname = "ahbk.ddns.net";
                passwordFile = config.age.secrets."ddns-password".path;
              };
            };
            networking.firewall.allowedTCPPorts = [ 80 443 ];

            security.acme = {
              acceptTerms = true;
              defaults.email = "alxhbk@proton.me";
            };

            services.nginx = {
              enable = true;
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedProxySettings = true;
              recommendedTlsSettings = true;
            };

            services.nginx.virtualHosts."_" = {
              default = true;
              locations."/" = {
                return = "444";
              };
            };

            environment.systemPackages = [ inputs.sverigesval.packages.${system}.bin ];
          }
        ];
      };
    };
  };
}
