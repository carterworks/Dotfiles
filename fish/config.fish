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
if command -qs bat
    alias cat="bat"
    alias less="bat"
end

# homebrew
if test -e /opt/homebrew/bin/brew
    eval "$(/opt/homebrew/bin/brew shellenv)"
end

# pnpm
if command -qs pnpm
    set -gx PNPM_HOME /Users/cmcbride/Library/pnpm
    if not string match -q -- $PNPM_HOME $PATH
        fish_add_path "$PNPM_HOME"
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

# Added by LM Studio CLI (lms)
if test -e ~/.lmstudio/bin
    fish_add_path ~/.lmstudio/bin
end
# End of LM Studio CLI section
fish_add_path ~/.local/bin
if test -f ~/.config/fish/secrets.local.fish
    source ~/.config/fish/secrets.local.fish
end

if command -qs tinty
    tinty generate-completion fish | source
end
