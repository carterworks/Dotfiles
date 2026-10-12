-- A keyboard-driven launcher should appear immediately, without a layer fade.
hl.layer_rule({
    name = "instant-vicinae",
    match = { namespace = "^vicinae$" },
    no_anim = true,
})

hl.window_rule({
    name = "kde-utility-dialogs",
    match = { class = "^(org.kde.systemsettings|systemsettings|org.kde.polkit-kde-authentication-agent-1|org.kde.kwalletd6|org.kde.kdeconnect.app)$" },
    float = true,
})

hl.window_rule({
    name = "picture-in-picture",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin = true,
})

-- Browser extension panels (for example Bitwarden's) are popup windows that
-- would otherwise open as full tiles in the scrolling layout. Zen titles every
-- one of them with an "Extension:" prefix, so float them all.
hl.window_rule({
    name = "zen-extension-windows",
    match = { class = "^zen(-beta|-twilight)?$", title = "^Extension:" },
    float = true,
})
