complete -c zellij -n "__fish_use_subcommand" -l max-panes -d 'Maximum panes on screen, caution: opening more panes will close old ones' -r
complete -c zellij -n "__fish_use_subcommand" -l data-dir -d 'Change where zellij looks for plugins' -r -F
complete -c zellij -n "__fish_use_subcommand" -l server -d 'Run server listening at the specified socket path' -r -F
complete -c zellij -n "__fish_use_subcommand" -s s -l session -d 'Specify name of a new session' -r
complete -c zellij -n "__fish_use_subcommand" -s l -l layout -d 'Name of a predefined layout inside the layout directory or the path to a layout file' -r -F
complete -c zellij -n "__fish_use_subcommand" -s c -l config -d 'Change where zellij looks for the configuration file' -r -F
complete -c zellij -n "__fish_use_subcommand" -l config-dir -d 'Change where zellij looks for the configuration directory' -r -F
complete -c zellij -n "__fish_use_subcommand" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_use_subcommand" -s V -l version -d 'Print version information'
complete -c zellij -n "__fish_use_subcommand" -s d -l debug -d 'Specify emitting additional debug information'
complete -c zellij -n "__fish_use_subcommand" -f -a "options" -d 'Change the behaviour of zellij'
complete -c zellij -n "__fish_use_subcommand" -f -a "setup" -d 'Setup zellij and check its configuration'
complete -c zellij -n "__fish_use_subcommand" -f -a "list-sessions" -d 'List active sessions'
complete -c zellij -n "__fish_use_subcommand" -f -a "attach" -d 'Attach to a session'
complete -c zellij -n "__fish_use_subcommand" -f -a "kill-session" -d 'Kill the specific session'
complete -c zellij -n "__fish_use_subcommand" -f -a "kill-all-sessions" -d 'Kill all sessions'
complete -c zellij -n "__fish_use_subcommand" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c zellij -n "__fish_seen_subcommand_from options" -l simplified-ui -d 'Allow plugins to use a more simplified layout that is compatible with more fonts (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l theme -d 'Set the default theme' -r
complete -c zellij -n "__fish_seen_subcommand_from options" -l default-mode -d 'Set the default mode' -r -f -a "{normal	In `Normal` mode, input is always written to the terminal, except for the shortcuts leading to other modes,locked	In `Locked` mode, input is always written to the terminal and all shortcuts are disabled except the one leading back to normal mode,resize	`Resize` mode allows resizing the different existing panes,pane	`Pane` mode allows creating and closing panes, as well as moving between them,tab	`Tab` mode allows creating and closing tabs, as well as moving between them,scroll	`Scroll` mode allows scrolling up and down within a pane,enter-search	`EnterSearch` mode allows for typing in the needle for a search in the scroll buffer of a pane,search	`Search` mode allows for searching a term in a pane (superset of `Scroll`),rename-tab	`RenameTab` mode allows assigning a new name to a tab,rename-pane	`RenamePane` mode allows assigning a new name to a pane,session	`Session` mode allows detaching sessions,move	`Move` mode allows moving the different existing panes within a tab,prompt	`Prompt` mode allows interacting with active prompts,tmux	`Tmux` mode allows for basic tmux keybindings functionality}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l default-shell -d 'Set the default shell' -r -F
complete -c zellij -n "__fish_seen_subcommand_from options" -l default-layout -d 'Set the default layout' -r -F
complete -c zellij -n "__fish_seen_subcommand_from options" -l layout-dir -d 'Set the layout_dir, defaults to subdirectory of config dir' -r -F
complete -c zellij -n "__fish_seen_subcommand_from options" -l theme-dir -d 'Set the theme_dir, defaults to subdirectory of config dir' -r -F
complete -c zellij -n "__fish_seen_subcommand_from options" -l mouse-mode -d 'Set the handling of mouse events (true or false) Can be temporarily bypassed by the [SHIFT] key' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l pane-frames -d 'Set display of the pane frames (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l mirror-session -d 'Mirror session when multiple users are connected (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l on-force-close -d 'Set behaviour on force close (quit or detach)' -r -f -a "{quit	,detach	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l scroll-buffer-size -r
complete -c zellij -n "__fish_seen_subcommand_from options" -l copy-command -d 'Switch to using a user supplied command for clipboard instead of OSC52' -r
complete -c zellij -n "__fish_seen_subcommand_from options" -l copy-clipboard -d 'OSC52 destination clipboard' -r -f -a "{system	,primary	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l copy-on-select -d 'Automatically copy when selecting text (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from options" -l scrollback-editor -d 'Explicit full path to open the scrollback editor (default is $EDITOR or $VISUAL)' -r -F
complete -c zellij -n "__fish_seen_subcommand_from options" -l disable-mouse-mode -d 'Disable handling of mouse events'
complete -c zellij -n "__fish_seen_subcommand_from options" -l no-pane-frames -d 'Disable display of pane frames'
complete -c zellij -n "__fish_seen_subcommand_from options" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_seen_subcommand_from setup" -l dump-layout -d 'Dump the specified layout file to stdout' -r
complete -c zellij -n "__fish_seen_subcommand_from setup" -l generate-completion -d 'Generates completion for the specified shell' -r
complete -c zellij -n "__fish_seen_subcommand_from setup" -l generate-auto-start -d 'Generates auto-start script for the specified shell' -r
complete -c zellij -n "__fish_seen_subcommand_from setup" -l dump-config -d 'Dump the default configuration file to stdout'
complete -c zellij -n "__fish_seen_subcommand_from setup" -l clean -d 'Disables loading of configuration file at default location, loads the defaults that zellij ships with'
complete -c zellij -n "__fish_seen_subcommand_from setup" -l check -d 'Checks the configuration of zellij and displays currently used directories'
complete -c zellij -n "__fish_seen_subcommand_from setup" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_seen_subcommand_from list-sessions" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_seen_subcommand_from attach; and not __fish_seen_subcommand_from options; and not __fish_seen_subcommand_from help" -l index -d 'Number of the session index in the active sessions ordered creation date' -r
complete -c zellij -n "__fish_seen_subcommand_from attach; and not __fish_seen_subcommand_from options; and not __fish_seen_subcommand_from help" -s c -l create -d 'Create a session if one does not exist'
complete -c zellij -n "__fish_seen_subcommand_from attach; and not __fish_seen_subcommand_from options; and not __fish_seen_subcommand_from help" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_seen_subcommand_from attach; and not __fish_seen_subcommand_from options; and not __fish_seen_subcommand_from help" -f -a "options" -d 'Change the behaviour of zellij'
complete -c zellij -n "__fish_seen_subcommand_from attach; and not __fish_seen_subcommand_from options; and not __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l simplified-ui -d 'Allow plugins to use a more simplified layout that is compatible with more fonts (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l theme -d 'Set the default theme' -r
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l default-mode -d 'Set the default mode' -r -f -a "{normal	In `Normal` mode, input is always written to the terminal, except for the shortcuts leading to other modes,locked	In `Locked` mode, input is always written to the terminal and all shortcuts are disabled except the one leading back to normal mode,resize	`Resize` mode allows resizing the different existing panes,pane	`Pane` mode allows creating and closing panes, as well as moving between them,tab	`Tab` mode allows creating and closing tabs, as well as moving between them,scroll	`Scroll` mode allows scrolling up and down within a pane,enter-search	`EnterSearch` mode allows for typing in the needle for a search in the scroll buffer of a pane,search	`Search` mode allows for searching a term in a pane (superset of `Scroll`),rename-tab	`RenameTab` mode allows assigning a new name to a tab,rename-pane	`RenamePane` mode allows assigning a new name to a pane,session	`Session` mode allows detaching sessions,move	`Move` mode allows moving the different existing panes within a tab,prompt	`Prompt` mode allows interacting with active prompts,tmux	`Tmux` mode allows for basic tmux keybindings functionality}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l default-shell -d 'Set the default shell' -r -F
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l default-layout -d 'Set the default layout' -r -F
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l layout-dir -d 'Set the layout_dir, defaults to subdirectory of config dir' -r -F
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l theme-dir -d 'Set the theme_dir, defaults to subdirectory of config dir' -r -F
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l mouse-mode -d 'Set the handling of mouse events (true or false) Can be temporarily bypassed by the [SHIFT] key' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l pane-frames -d 'Set display of the pane frames (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l mirror-session -d 'Mirror session when multiple users are connected (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l on-force-close -d 'Set behaviour on force close (quit or detach)' -r -f -a "{quit	,detach	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l scroll-buffer-size -r
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l copy-command -d 'Switch to using a user supplied command for clipboard instead of OSC52' -r
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l copy-clipboard -d 'OSC52 destination clipboard' -r -f -a "{system	,primary	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l copy-on-select -d 'Automatically copy when selecting text (true or false)' -r -f -a "{true	,false	}"
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l scrollback-editor -d 'Explicit full path to open the scrollback editor (default is $EDITOR or $VISUAL)' -r -F
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l disable-mouse-mode -d 'Disable handling of mouse events'
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -l no-pane-frames -d 'Disable display of pane frames'
complete -c zellij -n "__fish_seen_subcommand_from attach; and __fish_seen_subcommand_from options" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_seen_subcommand_from kill-session" -s h -l help -d 'Print help information'
complete -c zellij -n "__fish_seen_subcommand_from kill-all-sessions" -s y -l yes -d 'Automatic yes to prompts'
complete -c zellij -n "__fish_seen_subcommand_from kill-all-sessions" -s h -l help -d 'Print help information'
function __fish_complete_sessions
    zellij list-sessions 2>/dev/null
end
complete -c zellij -n "__fish_seen_subcommand_from attach" -f -a "(__fish_complete_sessions)" -d "Session"
complete -c zellij -n "__fish_seen_subcommand_from a" -f -a "(__fish_complete_sessions)" -d "Session"
complete -c zellij -n "__fish_seen_subcommand_from kill-session" -f -a "(__fish_complete_sessions)" -d "Session"
complete -c zellij -n "__fish_seen_subcommand_from k" -f -a "(__fish_complete_sessions)" -d "Session"
complete -c zellij -n "__fish_seen_subcommand_from setup" -l "generate-completion" -x -a "bash elvish fish zsh powershell" -d "Shell"
