{
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "Bibata-Modern-Classic";
    HYPRCURSOR_THEME = "24";
  };

  programs.fish.enable = true;

  users.groups.games = { };
  users.users.carter = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "games"
    ];
  };
}
