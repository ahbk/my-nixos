{ pkgs, user, ... }: {
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  environment.systemPackages = with pkgs; [
    pavucontrol
  ];
  users.users.${user}.extraGroups = [ "audio" ];
  security.polkit.enable = true;
}
