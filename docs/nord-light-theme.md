# Nord Light

Select `nord-light` with `dotfiles.desktopTheme.name` in
`nix/users/carter/home-manager.nix`. Nord Light is the selected theme; the
module's fallback default remains Everforest.

The shared desktop palette follows Ghostty's **Nord Light**, including its
`#e5e9f0` background, `#414858` foreground, `#d8dee9` selection, and adjusted
ANSI accents. Semantic link/status colors are darker for light-background
readability; the terminal's native ANSI palette is unchanged.

- Ghostty: built-in `Nord Light`.
- Helix: built-in `nord_light`.
- OpenCode: `nord`, explicitly in light mode.
- Herdr: terminal theme with shared UI color overrides.
- Zellij and btop: locally generated light themes, not their dark Nord ports.
- Zed: pinned `Nord Light` from `mikasius/zed-nord-theme`.
- Obsidian: pinned `Obsidian Nord` from `insanum/obsidian_nord`, in light mode.

Native editor ports have their own syntax/UI choices; they are not exact
copies of Ghostty's terminal colors. Other desktop integrations use the shared
semantic palette through the existing generators.

Apply and audit as described in [desktop-theme-implementation.md](desktop-theme-implementation.md).
Telegram and Heroic need their supported manual import/selection steps; use
the generated files named `nord-light` instead of `everforest-light-medium`.
