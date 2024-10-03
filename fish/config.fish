if command -qs starship
    starship init fish | source
end
if command -qs any-nix-shell
    any-nix-shell fish --info-right | source
end
if command -qs zoxide
    zoxide init fish | source
end
if command -qs hx
    set -gx EDITOR hx
end
if command -qs eza
    set -gx EZA_ICONS_AUTO true
    set -gx EZA_ICON_SPACING 2
    alias ls="eza --classify=auto --hyperlink --group-directories-first"
end
set -gx base16_fish_theme selenized-light
if test -n "$base16_fish_theme" && status --is-interactive
    base16-$base16_fish_theme
end
