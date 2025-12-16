# if the hm-session-vars.sh file exists, source it with babelfish
if test -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" && command -qs babelfish
    cat "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" | babelfish | source
end
if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
end
if command -qs mise
    mise activate fish | source
end
if status is-interactive
    # Cache shell tool inits (regenerate: rm ~/.cache/fish/*.fish)
    set -l cache_dir ~/.cache/fish
    mkdir -p $cache_dir

    if command -qs starship
        set -l cache $cache_dir/starship_init.fish
        if not test -f $cache
            starship init fish --print-full-init > $cache
        end
        source $cache
    end
    if command -qs zoxide
        set -l cache $cache_dir/zoxide_init.fish
        if not test -f $cache
            zoxide init fish --cmd cd > $cache
        end
        source $cache
    end
    if command -qs hx
        set -gx EDITOR hx
    else if command -qs helix
        set -gx EDITOR helix
        alias hx="helix"
    else if command -qs nvim
        set -gx EDITOR nvim
    else if command -qs vim
        set -gx EDITOR vim
    else if command -qs vi
        set -gx EDITOR vi
    else if command -qs micro
        set -gx EDITOR micro
    else if command -qs nano
        set -gx EDITOR nano
    end
    if command -qs eza
        set -gx EZA_ICONS_AUTO true
        set -gx EZA_ICON_SPACING 2
        alias ls="eza --classify=auto --group-directories-first"
    end
    if command -qs atuin
        set -l cache $cache_dir/atuin_init.fish
        if not test -f $cache
            atuin init fish > $cache
        end
        source $cache
        if command -qs fzf_configure_bindings
            fzf_configure_bindings --history=
        end
    end
    if command -qs yazi
        function yy
            set tmp (mktemp -t "yazi-cwd.XXXXXX")
            yazi $argv --cwd-file="$tmp"
            if read -z cwd <"$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
                builtin cd -- "$cwd"
            end
            rm -f -- "$tmp"
        end
    end
end
# homebrew - cache shellenv output (regenerate: rm ~/.cache/fish/brew_shellenv.fish)
if test -e /opt/homebrew/bin/brew
    set -l brew_cache ~/.cache/fish/brew_shellenv.fish
    if not test -s $brew_cache
        mkdir -p ~/.cache/fish
        /opt/homebrew/bin/brew shellenv fish > $brew_cache
    end
    source $brew_cache
end

# Added by LM Studio CLI (lms)
if test -e ~/.lmstudio/bin
    fish_add_path ~/.lmstudio/bin
end
# End of LM Studio CLI section
fish_add_path ~/.local/bin
if test -f ~/.config/fish/secrets.local.fish
    source ~/.config/fish/secrets.local.fish
end

if command -qs codex
    set -gx CODEX_HOME "$XDG_CONFIG_HOME/codex"
end
