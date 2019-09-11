# Initialize pyenv
if command -s pyenv
    set -x PYENV_ROOT $HOME/.pyenv
    set -x PATH $PYENV_ROOT/bin $PATH
    status --is-interactive; and . (pyenv init -|psub)
end
# Bootstrap fisher
if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end
# Initalize spaceship prompt
if command -s starship
    eval (starship init fish)
end
