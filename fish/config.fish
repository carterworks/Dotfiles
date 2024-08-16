# Initalize spaceship prompt
if command -qs starship
    starship init fish | source
end
if command -qs any-nix-shell
    any-nix-shell fish --info-right | source
end
if command -qs zoxide
    zoxide init fish | source
end
if command -qs micro && test $COLORTERM = "truecolor"
    set -gx MICRO_TRUECOLOR 1
end
if command -qs nvim
    set -gx EDITOR nvim
end
