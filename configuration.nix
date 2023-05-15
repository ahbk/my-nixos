# This is configuration.nix for friday
{ config, pkgs, lib, ... }: {

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/sda";
  };

  networking.hostName = "friday";
  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Stockholm";

  users.mutableUsers = false;

  users.users.frans = {
    isNormalUser = true;
    home = "/home/frans";
    extraGroups = [ "wheel" "networkmanager" "transmission" "audio" "adbusers" "video" "docker" "lxd" ];
    hashedPassword = "$6$PPO4I0Dw$H9COoSeK6FOMqucscb7fzq7lArI7d2hK1/I4Yh7RpzN8oX2LKg741ESqrKPdiglg1zCoUnJqJiU5E2HFrb7vO1";
  };

  environment.systemPackages = with pkgs; [
    wget dmenu mpv git mkpasswd gcc
    debootstrap
    pwgen
    gtypist
    xawtv
    xclip
    scrot
    silver-searcher
    # tor-browser-bundle-bin
    pavucontrol
    universal-ctags
    surf vimb qutebrowser firefox chromium
    signal-desktop
    lastpass-cli bitwarden-cli
    mupdf
    pciutils hwinfo lshw dmidecode
    zip unzip
    (st.override { conf = builtins.readFile ./st-0.8.5/config.def.h; })
    python310
    vimHugeX
    musescore
    feh
  ];

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    escapeTime = 10;
  };

  programs.adb.enable = true;

  virtualisation.docker.enable = true;

  programs.bash.shellAliases = {
    ll = "ls -lha";
    vim = "$EDITOR";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    configure = {
      customRC = builtins.readFile ./vim/init.vim;
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          nerdtree ctrlp sleuth vim-nix vimtex tagbar syntastic vim-svelte coc-tsserver ];
        opt = [ fugitive ];
      };
    };
  };

  programs.light.enable = true; # Needed for the /run/wrappers/bin/light SUID wrapper.
  services.actkbd = {
    enable = true;
    bindings = [
      { keys = [ 224 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -U 10"; }
      { keys = [ 225 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -A 10"; }
    ];
  };
  sound.enable = true;
  #sound.mediaKeys.volumeStep = "1000";
  hardware.pulseaudio.enable = true;
  hardware.bluetooth.enable = true;

  services.openssh.enable = true;
  services.transmission.enable = true;

  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
    windowManager.xmonad.enable = true;
    windowManager.xmonad.enableContribAndExtras = true;
    autoRepeatDelay = 175;
    autoRepeatInterval = 35;
    layout = "us,se";
    xkbOptions = "grp:alt_shift_toggle";
    libinput.enable = true;
  };

  services.udev = {
    # https://tracker.pureos.net/T683
    extraHwdb = ''
      evdev:atkbd:dmi:bvn*:bvr*:bd*:svnPurism*:pn*Librem13v2*:pvr*
      KEYBOARD_KEY_56=backslash
    '';
  };

  # the release version of the first install of this system (don't change)
  system.stateVersion = "20.03";
}
