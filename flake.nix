{
  description = "my system";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    nixpak.url = "github:nixpak/nixpak";
    nixpak.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # wkhtmltopdf is broken and unsafe, this is the context for running wkhtmltopdf as a nixpak
    nixpkgs-wkhtmltopdf.url = "github:NixOS/nixpkgs/c8d822252b86022a71dcc4f0f48bc869ef446401";
    nixpkgs-wkhtmltopdf.flake = false;
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    theme = import ./theme.nix;

    # custom packages not found in nixpkgs.pkgs
    pkgs' = import ./packages/all.nix { inherit pkgs; };

    # custom library functions not found in nixpkgs.lib
    lib' = import ./lib.nix {
      inherit (nixpkgs) lib;
      inherit pkgs;
    };

    # chunks of reusable `ahbk.*` configuration snippets
    edgechunks = import ./edgechunks.nix { inherit inputs system; };

    # Makes a home-manager configuration out of ahbk.*.<user> confs and the *-hm.nix modules.
    # This is for reusing NixOS's hm-config modules
    mkHomeConfiguration = user: cfg: inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs system theme; };
      modules = [ (import ./modules/all-hm.nix cfg user) ];
    };
  in

  with nixpkgs.lib;

  {
    homeConfigurations = {
      "frans@debian" = mkHomeConfiguration "frans" {
        user.frans = edgechunks.frans;
        shell.frans.enable = true;
        ide.frans.enable = true;
      };
    };

    nixosConfigurations = rec {

      # nixos@10.233.2.2 for testing
      # nixos-container create test --flake ~/Desktop/nixos
      container = test;
      test = nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib'; };
        modules = [
          ./hardware/container.nix
          ./modules/all.nix
          {
            ahbk.testuser = edgechunks.testuser;
            system.stateVersion = "23.11";
            networking.hostName = "test";
          }
        ];
      };

      laptop = nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib' theme; };
        modules = [
          ./hardware/laptop.nix
          ./modules/all.nix
          {
            ahbk = with edgechunks; {
              user = { inherit alex frans; };
              shell.frans.enable = true;
              ide.frans = {
                enable = true;
                postgresql = true;
                mysql = true;
                userAsTopDomain = false;
              };
              de.frans.enable = true;
              vd.frans.enable = true;
              laptop.enable = true;

              wgClient = {
                enable = true;
                host = "laptop";
                publicKey = "AiqJQGkt5f+jc70apQs3wcidw5QSXmzln2OzijpOUzY=";
                address = "10.0.0.2/24";
                allowedIPs = [ "10.0.0.0/24" ];
                endpoint = "ahbk.ddns.net:51820";
                keepalive = 25;
              };
            };

            system.stateVersion = "23.11";

            networking = {
              hostName = "laptop";
              nat = {
                enable = true;
                internalInterfaces = ["ve-+"];
                externalInterface = "wlp1s0";
              };
              networkmanager.unmanaged = [ "interface-name:ve-*" ];
              firewall.allowedTCPPorts = [ 3000 5173 8000 ];
            };

            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            swapDevices = [
              {
                device = "/swapfile";
                size = 8192;
              }
            ];

            services.dnsmasq = {
              enable = false;
              settings.address = "/.test/10.233.1.2";
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

      stationary = nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib' theme pkgs'; };
        modules = [
          ./hardware/stationary.nix
          ./modules/all.nix
          ({ config, pkgs', ... }: {
            networking.hostName = "stationary";
            system.stateVersion = "20.03";
            boot.loader.grub = {
              enable = true;
              device = "/dev/sda";
            };

            services.netdata.enable = true;
            services.nginx.virtualHosts."10.0.0.1".locations."/netdata/" = {
              proxyPass = "http://localhost:19999/";
            };

            networking.dhcpcd.runHook = ''
            if [ "$interface" = "wg0" ] && [ -n "$new_ip_address" ]; then echo "$interface got new address: $new_ip_address"; fi
            '';

            ahbk = with edgechunks; {
              user = { inherit frans; };
              shell.frans.enable = true;
              ide.frans = {
                enable = true;
                postgresql = true;
                mysql = true;
                userAsTopDomain = false;
              };

              wgServer = {
                enable = true;
                host = "stationary";
                address = "10.0.0.1/24";
                peers = {
                  stationary = {
                    key = "AiqJQGkt5f+jc70apQs3wcidw5QSXmzln2OzijpOUzY=";
                    address = "10.0.0.1";
                  };
                  laptop = {
                    key = "lmckXsECjZUgmWclkXUU4wvb5Vh30XNGxC68ChEs+j8=";
                    address = "10.0.0.2";
                  };
                  phone = {
                    key = "YOYtjFRc71iStHnN2lV3WoiOA743ljfYep6IyVJGUWg=";
                    address = "10.0.0.4";
                  };
                };
              };

              nginx = {
                enable = true;
                email = frans.email;
              };

              odoo = {
                enable = true;
                package = pkgs'.odoo;
                domain = "10.0.0.1";
                settings = {
                  options = {
                    db_user = "odoo";
                    db_name = "odoo";
                  };
                };
              };

              inadyn = {
                enable = true;
                providers."default@noip.com" = {
                  username = "alexander.holmback@gmail.com";
                  hostname = "ahbk.ddns.net";
                  passwordFile = config.age.secrets."ddns-password".path;
                };
              };

              wordpress.sites."test.esse.nu" = wordpress.sites."test.esse.nu";
            };

            age.secrets."ddns-password".file = ./secrets/ddns-password.age;

          })
        ];
      };

      glesys = nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs inputs system lib' theme; };
        modules = [
          ./hardware/glesys.nix
          ./modules/all.nix
          ({ config, ... }: {
            networking.hostName = "glesys";
            system.stateVersion = "23.11";

            ahbk = with edgechunks; {
              user = { inherit alex frans; };
              shell.frans.enable = true;
              ide.frans = {
                enable = true;
                postgresql = false;
                mysql = false;
                userAsTopDomain = false;
              };

              nginx = {
                enable = true;
                email = frans.email;
              };

              mail.enable = true;

              inherit chatddx sverigesval;
              wordpress.sites."esse.nu" = wordpress.sites."esse.nu";
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
          })
        ];
      };

    };
  };
}
