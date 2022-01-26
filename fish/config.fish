set pure_color_mute grey
# Initalize spaceship prompt
if command -qs starship
    starship init fish | source
end
if command -qs any-nix-shell
    any-nix-shell fish --info-right | source
end
