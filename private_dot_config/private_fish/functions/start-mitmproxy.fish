#!/usr/bin/env fish
function start-mitmproxy
    set -x NETWORK_DEVICE (networksetup -listallnetworkservices | fzf --height 25% --reverse --query "!An")
    echo "Selected '$NETWORK_DEVICE' as the network device"
    set -x PROXY_ADDRESS "localhost"
    set -x PROXY_PORT "8080"
    networksetup -setsecurewebproxy $NETWORK_DEVICE $PROXY_ADDRESS $PROXY_PORT off
    networksetup -setsecurewebproxystate $NETWORK_DEVICE on
    echo "Turned on secure web proxy for '$NETWORK_DEVICE' to $PROXY_ADDRESS:$PROXY_PORT"
    networksetup -setwebproxy  $NETWORK_DEVICE $PROXY_ADDRESS $PROXY_PORT off
    networksetup -setwebproxystate $NETWORK_DEVICE on
    echo "Turned on web proxy for '$NETWORK_DEVICE' to $PROXY_ADDRESS:$PROXY_PORT"
    mitmproxy $argv
    echo "mitmproxy exited"
    networksetup -setwebproxystate $NETWORK_DEVICE off
    echo "Turned off web proxy for '$NETWORK_DEVICE'"
    networksetup -setsecurewebproxystate $NETWORK_DEVICE off
    echo "Turned off secure web proxy for '$NETWORK_DEVICE'"
end
