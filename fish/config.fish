# if the hm-session-vars.sh file exists, source it with babelfish
if test -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" && command -qs babelfish
    cat "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" | babelfish | source
end
if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
end
if command -qs starship
    starship init fish | source
end
if command -qs any-nix-shell
    any-nix-shell fish --info-right | source
end
if command -qs zoxide
    zoxide init fish --cmd cd | source
end
if command -qs hx
    set -gx EDITOR hx
end
if command -qs eza
    set -gx EZA_ICONS_AUTO true
    set -gx EZA_ICON_SPACING 2
    alias ls="eza --classify=auto --group-directories-first"
end
set -gx base16_fish_theme selenized-light
if test -n "$base16_fish_theme" && status --is-interactive
    base16-$base16_fish_theme
end
if command -qs fnm
    fnm env --use-on-cd --shell fish | source
end

# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# pnpm
if command -qs pnpm
    set -gx PNPM_HOME "/Users/cmcbride/Library/pnpm"
    if not string match -q -- $PNPM_HOME $PATH
        set -gx PATH "$PNPM_HOME" $PATH
    end
    # completions
    if status --is-interactive
        # Only source the definitions once per session.
        if not functions -q _pnpm_completion
            pnpm completion fish | source
        end
    end
end
# pnpm end
