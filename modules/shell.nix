{ pkgs, user, isHM, ... }: let
  hm = {

    home.username = user;
    home.homeDirectory = "/home/${user}";

    programs.bash.bashrcExtra = ''
      export PATH="$PATH:$HOME/.local/bin"
    '';
    home.shellAliases = {
      nix-store-size = ''ls /nix/store | wc -l'';
      f = ''fzf | xargs -I {} rifle {}'';
      l = ''eza -la --icons=auto'';
      ll = ''eza'';
      grep = ''grep --color=auto'';
    };

    programs.bash = {
      enable = true;
    };

    programs.zoxide = {
      enable = true;
    };

    programs.fzf = {
      enable = true;
    };

    programs.starship = {
      enable = true;
      settings = {
        add_newline = false;
        aws.disabled = true;
        gcloud.disabled = true;
        line_break.disabled = true;
      };
    };

    programs.ssh = {
      enable = true;
    };

    home.packages = with pkgs; [ 
      ranger
      lazygit
      silver-searcher
      ripgrep
      fd
      eza
      wget
    ];
  };
in if isHM then hm else {
  home-manager.users.${user} = hm;
}
