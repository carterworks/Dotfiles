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

-- Zen opens browser popups -- extension panels, the "Sign in with Google"
-- window, and the like -- as ordinary sibling windows. Each carries the
-- browser's class and its "Zen Browser" initial title, exactly like a tab, and
-- Zen only sets the real title once the window has mapped. A static float rule
-- is matched against the initial title, so it can never recognise one of these;
-- catch the title event instead and float the window when its finished title
-- names it as a popup.
local function is_zen(w)
    return w.class:match("^zen") ~= nil
end

local zen_popup_titles = {
    "^Extension:",                 -- extension panels, for example Bitwarden
    "^Sign in %- Google Accounts", -- the "Sign in with Google" flow
}

hl.on("window.title", function(w)
    if not is_zen(w) then return end

    -- A popup is never the only window of its browser; the window that opened
    -- it is still up beside it. Requiring a sibling keeps a lone browsing
    -- window from floating when one of its tabs happens to carry a matching
    -- title.
    local sibling = false
    for _, other in ipairs(hl.get_windows()) do
        if other.address ~= w.address and is_zen(other) then
            sibling = true
            break
        end
    end
    if not sibling then return end

    for _, pattern in ipairs(zen_popup_titles) do
        if w.title:match(pattern) then
            hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
            return
        end
    end
end)
