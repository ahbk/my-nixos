{ user, ... }: {
  home-manager.users.${user} = {
    programs.bash = {
      shellAliases = {
        battery = ''cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status'';
      };
    };
  };
}
