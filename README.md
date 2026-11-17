<p align="center">
  <img src="./.github/logo.png" width="150" height="150" alt="plugin-logo">
</p>

# physical-keyboard.nvim

Use your national keyboard layout in Normal, Visual and Operator-pending modes.
Type `сшц` and Neovim runs `ciw`; plugin shortcuts such as `<leader>ff` and
`gcc` keep working. Insert-mode text is never translated.

The plugin is a thin MIT wrapper around Neovim's built-in `langmap`, a mapping
mirroring layer, platform layout detection and command-line aliases. No
external binary is downloaded and no GPL code is bundled.

## Features

- **Built-in commands** — `ciw`, `daw`, `gcc`, `%`, `f`/`t`, marks and
  registers work through `langmap`, in C.
- **Plugin mappings** — mappings registered with `vim.keymap.set()`,
  `nvim_set_keymap()` or `nvim_buf_set_keymap()` are mirrored to the active
  layout, including lazy-loaded plugins, `<Leader>` and `<C-...>` mappings.
- **Automatic detection** — niri, Sway, Hyprland, GNOME, KDE, X11, IBus,
  Fcitx, macOS and Windows adapters. Detection is throttled and asynchronous.
- **18 bundled layouts** — Russian, German, French, Spanish, Italian,
  Ukrainian, Belarusian, Czech, Swedish, Turkish, Greek, Hebrew, Arabic,
  Persian, Kazakh, Korean, Dvorak, Colemak. Custom layouts are supported.
- **which-key aware** — mirrored mappings can be hidden, grouped with the
  original label, or appended to the original shortcut label.
- **Native listing aware** — `:map`, `:nmap`, Telescope, Snacks and other
  keymap pickers show originals only; mirrored bindings stay active.
- **Command-line aliases** — `:ц` → `:w`, `:цй` → `:wq`, and more via
  `cnoreabbrev`.
- **Configuration** — plugin `opts`, an external Lua file, UI overrides and
  `PKB_*` environment variables.
- **Statusline, events, echo mode, `:checkhealth`** and a floating dashboard
  (`:PhyKeyboardUI`).
- **Insert mode is untouched**, and `langremap` stays off.

## Requirements

- Neovim 0.10+
- Optional detection helper for your environment (`xkb-switch` on X11,
  `im-select` on macOS/Windows). Without one, translation still works with a
  safe merged map.

## Installation

lazy.nvim:

```lua
{
  "qFioofa/physical-keyboard.nvim",
  event = { "VeryLazy" },
  opts = {
    active_layouts = { "ru" },
  },
}
```

Manual:

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
})
```

`VeryLazy` lets other plugins register their mappings first; mappings created
later are still caught by the keymap hook.

## Quick start

Russian + English with automatic switching (recommended):

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  fallback = "unique",
  detect = { enabled = true },
})
```

Russian only, no detection:

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { enabled = false },
  fallback = "ru",
})
```

Several layouts:

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru", "de", "fr" },
  fallback = "unique",
})
```

Remote Neovim over SSH (local layout is irrelevant):

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { remote = "auto" }, -- detection off over SSH
  fallback = "ru",
})
```

## Configuration

Only the commonly changed keys are shown; every option lives in
`:help physical-keyboard-config`.

```lua
require("physical-keyboard").setup({
  enable = true,
  notify = "errors",             -- "all" | "errors" | "off"
  active_layouts = { "ru" },     -- {} enables every bundled layout
  fallback = "unique",           -- "unique" | "<id>" | false
  toggle_key = false,            -- e.g. "<leader>tk"
  config_file = false,           -- true or a custom path
  overrides = true,              -- UI state in stdpath("state")

  detect = {
    enabled = true,
    remote = "auto",
    min_interval = 300,
    async = true,
    events = { "FocusGained", "VimResume", "InsertLeave" },
  },

  mappings = {
    enabled = true,
    modes = { "n", "x", "s", "o" },
    exclude = {},                -- LHS strings or Lua patterns
    extra = {},                  -- [english lhs] = native lhs
  },

  which_key = {
    enabled = true,
    display = nil,               -- nil / "hide": hide mirrors, keep originals
    relative_group = false,      -- copy the original group label to the mirror
    alongside = false,           -- append mirrored keys to the original label
    separator = "\\",
  },

  native = {
    enabled = true,
    commandline = true,          -- :map/:nmap output
    api = true,                  -- nvim_get_keymap/nvim_buf_get_keymap
  },

  cmdline = {
    enabled = true,
    aliases = {},                -- extra English Ex commands
    extra = {},                  -- [native] = English
  },
})
```

Precedence: defaults → config file → `setup()` opts → UI overrides →
`PKB_*` variables. The override file is written by the UI, never by editing
your Lua config.

### which-key integration

which-key otherwise lists every mirrored shortcut as a separate category. The
`which_key` section controls that presentation:

- `display = nil` or `"hide"` (default) hides mirrored entries; only the
  original English shortcuts remain.
- `relative_group = true` shows mirrored shortcuts under the translated prefix
  with the original group label (`<leader>а` labelled `find`). which-key cannot
  place a translated key inside the original `<leader>f` group; the mirrored
  prefix is the physical equivalent.
- `alongside = true` appends mirrored keys to the original label, for example
  `Find files \ ъъаа`, using `separator`.

Precedence is `alongside` → `relative_group` → `hide`. Both which-key 3.x and
2.x are supported; group labels are copied when which-key exposes them.

With the default `native.api = true`, disabling `which_key` does not bring
mirrored entries back to which-key; set `native.api = false` if you want Lua
consumers to see the mirrors again.

### Native mapping listings

Mirrors are real keymaps, so native listings would otherwise show both the
original and the national variant. The `native` section controls the cleanup:

- `commandline = true` filters `:map`, `:nmap`, `:verbose map`,
  `:filter /…/ nmap` and `:map <buffer>`. Mirrors are removed only while the
  native command is executing and restored immediately afterwards. Map
  definitions are never executed with mirrors removed.
- `api = true` filters `vim.api.nvim_get_keymap()` and
  `nvim_buf_get_keymap()`. This covers Snacks, Telescope, which-key, mini.extra
  and other Lua consumers.
- The getter filter is read-only: real mirror bindings stay active in every
  window and buffer. Only the returned listing is filtered.
- `<Tab>` completion for `:map`/`:nmap` is intentionally not filtered; it may
  show mirrors. The listing produced after pressing Enter is clean.
- `maparg()` and `getcompletion(…, "mapping")` are not filtered because which-key
  triggers and other plugins use them for actual key handling.
- Programmatic `<Cmd>nmap<CR>`, `:execute "nmap"`, `:redir` captures and
  multi-command `|` lines are not filtered.

`native = false` disables the whole layer. To keep native `:map` output clean
but let Snacks/Telescope see mirrors, use `native = { api = false }`.

## Commands

| Command                                         | Purpose                                    |
| ----------------------------------------------- | ------------------------------------------ |
| `:PhyKeyboardStatus`                            | Current layout, langmap size, mappings     |
| `:PhyKeyboardDetect`                            | Raw OS detection result                    |
| `:PhyKeyboardDoctor [--json]`                   | Full environment report                    |
| `:PhyKeyboardConfig [--json]`                   | Effective configuration                    |
| `:PhyKeyboardUI`                                | Floating dashboard                         |
| `:PhyKeyboardUse <id>`                          | Force a layout (`en` disables translation) |
| `:PhyKeyboardAuto`                              | Return to detection                        |
| `:PhyKeyboardRefresh`                           | Re-run layout detection                    |
| `:PhyKeyboardEnable/Disable/Toggle`             | Control the plugin                         |
| `:PhyKeyboardMappings`                          | Re-mirror registered mappings              |
| `:PhyKeyboardEditConfig` / `:PhyKeyboardReload` | External config file                       |
| `:PhyKeyboardConfigReset`                       | Delete UI overrides                        |
| `:PhyKeyboardEcho [on\|off]`                    | Raw key diagnostic mode                    |

## Statusline

```lua
vim.o.statusline = "%{v:lua.require'physical-keyboard'.statusline()} %f"
```

The component returns `RU`, `EN`, `--`, or a custom value via
`statusline({ uppercase = false, english = "EN", unknown = "--" })`. The same
state is exposed as `vim.g.physical_keyboard_layout` and the
`PhysicalKeyboardLayoutChanged` event.

## Examples and reference files

Start from the smallest matching file:

| File                                                       | Use it for                  |
| ---------------------------------------------------------- | --------------------------- |
| [`examples/lazy.lua`](examples/lazy.lua)                   | lazy.nvim spec              |
| [`examples/russian-only.lua`](examples/russian-only.lua)   | one layout, no detection    |
| [`examples/multilingual.lua`](examples/multilingual.lua)   | several layouts             |
| [`examples/remote.lua`](examples/remote.lua)               | SSH / remote Neovim         |
| [`examples/config-file.lua`](examples/config-file.lua)     | external config file        |
| [`examples/custom-layout.lua`](examples/custom-layout.lua) | custom layout map           |
| [`examples/mappings.lua`](examples/mappings.lua)           | exclusions, extras, which-key, aliases |
| [`examples/lualine.lua`](examples/lualine.lua)             | lualine component           |

Reference documentation:

- `doc/physical-keyboard.txt` — complete English help.
- `doc/physical-keyboard.ru.txt` — full Russian translation.
- `AGENTS.md` — architecture, invariants and the AI configuration playbook.
- `lua/physical-keyboard/config.lua` — defaults and validation.
- `lua/physical-keyboard/layouts/data.lua` — bundled layout maps.

## Important notes

- `langmap` is physical: on Russian ЙЦУКЕН the US `:` position produces `Ж`.
  To save and quit type `Ж ц й Enter` (`:` `wq`).
- An English OS layout disables translation; it never falls back to a national
  layout.
- Insert-mode literal text is intentionally never translated.
- Command-line translation is alias-based; arbitrary Ex commands are not
  rewritten.

## Verify

```vim
:PhyKeyboardStatus
:PhyKeyboardDetect
:checkhealth physical-keyboard
```

```sh
nvim --headless --clean -u NONE -l tests/test_all.lua
```

## License

MIT. Layout data from [ai/convert-layout](https://github.com/ai/convert-layout)
(MIT); mapping mirroring inspired by
[Wansmer/langmapper.nvim](https://github.com/Wansmer/langmapper.nvim) (MIT);
unique-submap idea from
[mrsobakin/multilayout.nvim](https://github.com/mrsobakin/multilayout.nvim)
(GPL-3.0, no code copied).
