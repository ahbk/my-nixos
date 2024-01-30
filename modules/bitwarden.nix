{ pkgs, user, ... }: {
  home-manager.users.${user} = {
    programs.bash = {
      initExtra = ''
        pwu() {
        bw unlock --raw > ~/.bwsession
        }
        pw() {
        BW_SESSION=$(<~/.bwsession) bw get password $@ | wl-copy
        }
      '';
    };
    home.packages = with pkgs; [
      bitwarden-cli
      wl-clipboard
    ];
  };
}
