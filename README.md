# Omaleader

A LazyVim / which-key style leader menu for [Omarchy](https://omarchy.org/).
Press a leader shortcut, then plain single keys (`w` `r` `l l l`) instead of
finger-twisting chords. A popup at the bottom of the screen lists the keys
available at each step, so you don't have to remember them.

It's an Omarchy shell plugin (QML), so it follows the current Omarchy theme.

## Install

```sh
git clone <this repo> ~/Dev/omaleader
ln -s ~/Dev/omaleader ~/.config/omarchy/plugins/tjtuom.omaleader
```

Enable it in `~/.config/omarchy/shell.json`:

```json
"plugins": [
  { "id": "tjtuom.omaleader" }
]
```

Bind a leader key in Hyprland, e.g. `~/.config/hypr/omaleader.lua` required
from `hyprland.lua`:

```lua
o.rebind("SUPER + SPACE", "Leader menu", hl.dsp.global("omaleader:toggle"), { submap_universal = true })

-- Omaleader switches Hyprland to this submap while it's open, so a still-held
-- Super doesn't turn the next key into a Super bind (Super+W closing a window).
hl.define_submap("omaleader", function()
  hl.bind("SUPER + F23", hl.dsp.no_op()) -- a submap needs one bind to exist
end)
```

## Keymap

Your keymap lives in `~/.config/omarchy/omaleader.jsonc`. If that file doesn't
exist, the bundled `keymap.example.jsonc` is used: copy it there as a starting
point. Saved changes apply immediately.

```jsonc
{
  "w": { "label": "Window", "keys": {
    "q": { "label": "Close", "dispatch": "hl.dsp.window.close()" },
    "r": { "label": "Resize", "keys": {
      "l": { "label": "Wider", "dispatch": "hl.dsp.window.resize({ x = 50, y = 0, relative = true })", "stay": true },
    }},
  }},
  "space": { "label": "Omarchy menu", "exec": "omarchy-menu toggle root" },
}
```

Each key is a single character (case-sensitive) or one of `space`, `tab`,
`enter`, `left`, `right`, `up`, `down`. Entry fields:

| Field      | Meaning |
|------------|---------|
| `label`    | Text shown next to the key. |
| `keys`     | Makes the entry a group with its own nested keymap. |
| `dispatch` | Hyprland Lua dispatcher, same syntax as `bindings.lua` (`hl.dsp.…`, Omarchy's `o.…` helpers). |
| `exec`     | Shell command, run with `bash -lc`. |
| `stay`     | `true` keeps the popup open after running, so the key can repeat. |

In the popup, Backspace goes up a level and Esc closes it.

If you create `omaleader.jsonc` while the shell is running on the example,
run `omarchy-shell shell rescanPlugins` once so it starts watching your file.

## IPC

```sh
omarchy-shell omaleader toggle   # or: hide, isOpen
```
