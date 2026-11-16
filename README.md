# physical-keyboard.nvim

Use Neovim in your native keyboard layout without switching to English for
Normal-mode commands.

Type `сшц` and Neovim sees `ciw`. Type `:ц` and Neovim runs `:w`. Your plugin
shortcuts (`<leader>ff`, `gcc`, LSP mappings, …) keep working too. Insert-mode
text is left completely untouched.

The plugin is a thin, MIT-licensed wrapper around three proven layers:

- **`langmap`** — Neovim's built-in, C-level translation of Normal/Visual/
  Operator-pending keys;
- **a mapping mirroring layer** — inspired by
  [langmapper.nvim](https://github.com/Wansmer/langmapper.nvim) (MIT);
- **a layout detection layer** — small adapters for X11, Wayland compositors,
  macOS and Windows.

No external binary is downloaded and no GPL code is bundled.

## Features

- **Motions and operators** — `ciw`, `daw`, `gcc`, `gg`, `%`, `f`/`t`, marks,
  registers, etc. are handled by `langmap`.
- **Plugin mappings** — every mapping registered through
  `vim.keymap.set`/`nvim_set_keymap`/`nvim_buf_set_keymap` is mirrored to the
  national layout, including lazy-loaded plugins, `<C-…>` combinations,
  `<Leader>` sequences and Lua callbacks.
- **Mapping filters** — exclude noisy shortcuts, add explicit variants.
- **Command-line** — common Ex commands get `cnoreabbrev` aliases: `:ц` → `:w`,
  `:й` → `:q`, `:цй` → `:wq`, and so on.
- **Automatic layout detection** — X11, Sway, Hyprland, niri, GNOME, KDE,
  IBus, Fcitx, macOS and Windows adapters, plus a safe fallback when detection
  is not available. Detection is asynchronous after startup and throttled.
- **18 bundled layouts** — Russian, German, French, Spanish, Italian,
  Ukrainian, Belarusian, Czech, Swedish, Turkish, Greek, Hebrew, Arabic,
  Persian, Kazakh, Korean, Dvorak and Colemak.
- **External configuration** — keep settings in
  `~/.config/nvim/physical-keyboard.lua`, reload them at runtime, override
  with `PKB_*` environment variables.
- **Statusline and events** — `statusline()`, `vim.g.physical_keyboard_layout`,
  and `User PhysicalKeyboardLayoutChanged`.
- **AI-friendly** — `:PhyKeyboardDoctor --json` and a complete `AGENTS.md`
  playbook let an assistant configure the plugin for a specific user.
- **No insert-mode interference** — literal text is never remapped.
- **`langremap` is disabled** — mappings are not re-translated recursively.
- **`:checkhealth physical-keyboard`** — shows the detected provider, current
  layout, langmap size and mirrored mappings.

## Requirements

- Neovim **0.10+** (LuaJIT).
- Optional, but recommended: a layout detection tool for your environment (see
  the table below). Without it the plugin still translates motions using a safe
  merged map.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "qFioofa/physical-keyboard.nvim",
  event = { "VeryLazy" },
  opts = {
    active_layouts = { "ru" },
  },
}
```

`opts` makes lazy.nvim call `require("physical-keyboard").setup(opts)`
automatically. `VeryLazy` is recommended so that mappings from other plugins
already exist when the mirroring layer starts. Mappings created later are still
caught through the keymap API hook.

Manual setup:

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
})
```

## Quick start

```lua
-- Russian only, no detection:
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { enabled = false },
  fallback = "ru",
})
```

```lua
-- Russian + English with automatic switching:
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { enabled = true },
  fallback = "unique",
})
```

See [examples/](examples/) for more recipes.

## Configuration

```lua
require("physical-keyboard").setup({
  enable = true,
  notify = "errors",          -- "all" | "errors" | "off"

  -- Layouts you use. Defaults to { "ru" }.
  -- Use an empty table ({}) to enable every bundled layout.
  active_layouts = { "ru" },

  -- What to do when the active layout is unknown:
  --   "unique"  - keep only non-conflicting pairs
  --   "<id>"    - always use this layout
  --   false     - leave 'langmap' empty
  fallback = "unique",

  toggle_key = false,         -- e.g. "<leader>tk"

  detect = {
    enabled = true,
    provider = nil,           -- force one adapter, e.g. "niri"
    providers = nil,          -- allowlist, e.g. { "niri", "sway" }
    remote = "auto",          -- "auto" disables detection over SSH
    min_interval = 300,       -- ms; throttles detection checks
    timeout = 500,            -- ms per detection command
    events = { "FocusGained", "VimResume", "InsertLeave" },
    async = true,
    on_change = nil,          -- function(info) ... end
  },

  langmap = {
    enabled = true,
  },

  mappings = {
    enabled = true,
    hack_keymap = true,       -- wrap nvim_*_set_keymap to catch lazy plugins
    automapping = true,       -- mirror already registered mappings
    modes = { "n", "x", "s", "o" }, -- add "i" for Insert-mode plugin mappings
    exclude = {},             -- LHS strings / Lua patterns
    extra = {},               -- [english lhs] = native lhs
  },

  cmdline = {
    enabled = true,
    aliases = {},             -- extra English Ex commands
    extra = {},               -- [native] = English
  },

  echo = {
    enabled = false,
    mode = "all",
  },
})
```

`notify = false` means `"errors"`. Use `"off"` to silence the plugin entirely.

### External config file

Keep settings outside `init.lua`:

```lua
require("physical-keyboard").setup({
  config_file = true, -- ~/.config/nvim/physical-keyboard.lua
})
```

A custom path is also accepted: `config_file = "~/.config/nvim/pkb.lua"`.

The file returns a table:

```lua
return {
  active_layouts = { "ru" },
  detect = { enabled = true },
}
```

Commands:

- `:PhyKeyboardEditConfig` — open or create the file (with a template);
- `:PhyKeyboardReload` — re-run `setup()` and re-read the file;
- `:PhyKeyboardConfig [--json]` — show the effective configuration.

Precedence: defaults → config file → `setup()` options → environment variables.

### Environment variables

| Variable | Effect |
|----------|--------|
| `PKB_CONFIG` | load a config file even without `config_file` |
| `PKB_LAYOUT` | force layout(s) for this run, comma-separated |
| `PKB_DISABLE=1` | disable the plugin for this run |
| `PKB_DEBUG=1` | enable echo, debug mode and all notifications |
| `PKB_NOTIFY` | `all`, `errors` or `off` |

```sh
PKB_LAYOUT=de nvim
PKB_DISABLE=1 nvim
PKB_DEBUG=1 nvim
```

Set `env = false` to ignore all `PKB_*` variables.

## Migrating from 0.x

- `active_layouts` is still accepted (string or list).
- `userLayouts` is still accepted. A layout is now a plain table instead of a
  `Layout` object:

```lua
require("physical-keyboard").setup({
  active_layouts = { "my-layout" },
  userLayouts = {
    ["my-layout"] = {
      title = "My layout",
      names = { "my-layout", "My Layout" }, -- used by detection
      map = {
        ["q"] = "й",
        ["w"] = "ц",
        -- English character -> native character
      },
    },
  },
})
```

Uppercase variants are generated automatically for cased letters.

## Default layouts

| id | Layout | id | Layout |
|----|--------|----|--------|
| `ru` | Russian | `uk` | Ukrainian |
| `de` | German (QWERTZ) | `by` | Belarusian |
| `fr` | French (AZERTY) | `cs` | Czech |
| `es` | Spanish | `sv` | Swedish |
| `it` | Italian | `tr` | Turkish |
| `gr` | Greek | `he` | Hebrew |
| `ar` | Arabic | `fa` | Persian |
| `kk` | Kazakh | `kr` | Korean |
| `dvorak` | Dvorak | `colemak` | Colemak |

Layout data is generated from
[ai/convert-layout](https://github.com/ai/convert-layout) (MIT).

## Layout detection

| Environment | Adapter |
|-------------|---------|
| niri | `niri msg -j keyboard-layouts` |
| Sway / wlroots | `swaymsg -t get_inputs -r` |
| Hyprland | `hyprctl devices -j` |
| GNOME | `gsettings get org.gnome.desktop.input-sources mru-sources` |
| KDE | `qdbus org.kde.keyboard …getLayout` |
| X11 | `xkb-switch -p`, then `setxkbmap -query` |
| IBus | `ibus engine` |
| Fcitx | `fcitx5-remote -n` |
| macOS | `im-select`, then `defaults read com.apple.HIToolbox` |
| Windows | `im-select.exe`, then PowerShell |

Detection runs on the configured events, is throttled by `min_interval`, and is
asynchronous by default. It also switches `langmap` back to empty when the OS
reports a plain English layout. A layout reported by the adapter is matched
against **all** bundled layouts and added at runtime, so a German user gets
working translations even with the default `active_layouts = { "ru" }`.

On SSH the local layout is irrelevant. `detect.remote = "auto"` disables
detection; use `active_layouts`, `fallback`, or `:PhyKeyboardUse`.

If no adapter works, `fallback = "unique"` keeps a conflict-free subset of the
active layouts so motions still work.

`:PhyKeyboardDoctor [--json]` lists every adapter, its raw answer and the
available helper binaries. `:PhyKeyboardDetect` shows the active result.

## Mapping mirroring

Every mapping is duplicated to the national layout. `<Plug>`, `<Sid>` and
`<Snr>` mappings are skipped.

```lua
-- Disable mirroring; only built-in motions are translated:
mappings = { enabled = false },

-- Do not mirror Telescope leader shortcuts:
mappings = { exclude = { "<Leader>f", "<C%-" } },

-- Add an explicit native variant:
mappings = { extra = { ["<Leader>zz"] = "<Leader>ZZ" } },
```

`exclude` entries are compared to the raw LHS and used as Lua patterns.
`exclude` wins over `extra`.

## Command-line aliases

Common Ex commands are registered with `cnoreabbrev`: `:ц` → `:w`,
`:цй` → `:wq`, and so on.

```lua
cmdline = {
  aliases = { "tabnew", "resize" }, -- extra English commands
  extra = { ["цц"] = "w" },         -- explicit native -> English
},
```

Runtime:

```vim
:PhyKeyboardAliases
:PhyKeyboardAliases add цц w
:PhyKeyboardAliases remove цц
```

## Commands

| Command | Description |
|---------|-------------|
| `:PhyKeyboard` | General information |
| `:PhyKeyboardStatus` | Detection, language map and mapping status |
| `:PhyKeyboardConfig [--json]` | Effective configuration |
| `:PhyKeyboardDoctor [--json]` | Full environment report |
| `:PhyKeyboardList` | List bundled layouts |
| `:PhyKeyboardDetect` | Show the raw detection result |
| `:PhyKeyboardEnable` / `:PhyKeyboardDisable` | Enable or disable the plugin |
| `:PhyKeyboardToggle` | Toggle the plugin |
| `:PhyKeyboardUse <layout>` | Force a layout (`en` disables translation) |
| `:PhyKeyboardAuto` | Return to automatic detection |
| `:PhyKeyboardRefresh` | Re-run detection now |
| `:PhyKeyboardMappings` | Re-mirror all registered mappings |
| `:PhyKeyboardAliases` | List or edit command-line aliases |
| `:PhyKeyboardEcho [on\|off]` | Toggle the echo keyboard |
| `:PhyKeyboardEchoMode [mode]` | Show or set the echo mode |
| `:PhyKeyboardNotify [mode]` | `all`, `errors`, `off` |
| `:PhyKeyboardCmdline [on\|off]` | Toggle command-line aliases |
| `:PhyKeyboardEditConfig` | Open or create the external config file |
| `:PhyKeyboardReload` | Reload `setup()` and the external config file |

Backwards-compatible commands: `:PhyKeyboardEnableLayout`,
`:PhyKeyboardDisableLayout`, `:PhyKeyboardSet`.

## Statusline

```lua
vim.o.statusline = "%{v:lua.require'physical-keyboard'.statusline()} %f"
```

lualine:

```lua
{
  function()
    return require("physical-keyboard").statusline()
  end,
}
```

Options:

```lua
require("physical-keyboard").statusline({
  uppercase = false,
  english = "ENG",
  unknown = "--",
  prefix = "",
  suffix = "",
})
```

`layout_info()` returns the layout id, raw OS value, provider and English flag.
`vim.g.physical_keyboard_layout` contains `ru`, `de`, `en` or `""`.

## Events

- `PhysicalKeyboardEnabled`
- `PhysicalKeyboardDisabled`
- `PhysicalKeyboardLayoutChanged`
- `PhysicalKeyboardConfigReloaded`

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "PhysicalKeyboardLayoutChanged",
  callback = function(args)
    vim.g.my_layout = args.data.id or "en"
  end,
})
```

The same data is passed to `detect.on_change`.

## AI configuration

An assistant can configure the plugin from a natural-language request. The
full playbook lives in [AGENTS.md](AGENTS.md). The machine-readable entry point
is:

```vim
:PhyKeyboardDoctor --json
```

or, from a shell:

```sh
nvim --headless \
  -c 'lua print(vim.json.encode(require("physical-keyboard").doctor({ probe = true })))' \
  -c qa 2>&1
```

The report contains the OS/session, available detection adapters and binaries,
the effective config and source, active layouts, and recommendations. The
assistant should choose a provider, patch only the `opts` table, and verify with
`:PhyKeyboardStatus`, `:PhyKeyboardDetect`, `:PhyKeyboardConfig --json`, and
`:checkhealth physical-keyboard`.

## Echo keyboard

```vim
:PhyKeyboardEcho on
:PhyKeyboardEchoMode debug
```

Modes: `all`, `byte`, `hex`, `raw`, `code`, `minimal`, `debug`.

## How it works

1. `langmap` translates characters typed in Normal/Visual/Select/Operator-pending
   modes. Neovim does this in C, so every built-in command is covered.
2. Because mappings are matched on their raw left-hand side, the plugin mirrors
   every registered mapping to the active layouts. This is done by wrapping the
   low-level `nvim_set_keymap`/`nvim_buf_set_keymap` API, so lazy-loaded plugins
   are covered as well.
3. `langmap` is disabled while entering a command line, so common Ex commands
   are translated with `cnoreabbrev` aliases.
4. A platform adapter reports the active OS layout and selects the matching
   `langmap`.

### Entering the command line

`langmap` is **physical-position based**: every character is translated to the
key at the same position on a US layout. On Russian ЙЦУКЕН the printed `:`
lives on Shift+6, while the US `:` lives on Shift+; — so to open the command
line you press the physical US `:` position, which produces `Ж`, and `langmap`
turns it into `:`.

For example, to save and quit from a Russian layout:

```text
Ж ц й Enter      " Ж -> :, цй -> wq
```

If you prefer to keep the labelled `:` key working as a command-line key, add a
custom layout map that omits the conflicting pair, or bind `:` explicitly.

## Help

```vim
:help physical-keyboard
:help physical-keyboard-ru
```

The Russian help file is a full translation:
`doc/physical-keyboard.ru.txt`.

## Troubleshooting

- **Shortcuts do not work in Normal mode** — check `:PhyKeyboardStatus` and
  run `:PhyKeyboardMappings` after lazy-loaded plugins have loaded.
- **`:wq` does not work from a Russian layout** — use the physical US `:`
  position (`Ж` on ЙЦУКЕН): `Ж ц й Enter`.
- **E357: 'langmap': Matching character missing** — a plugin bug; please report
  it with `:PhyKeyboardDoctor --json`.
- **Detection is disabled over SSH** — intentional with `detect.remote =
  "auto"`. Set `detect.remote = false` or use `active_layouts`.
- **The plugin does nothing** — `setup()` was not called. With lazy.nvim use
  `opts` or a `config` function.
- **Too many notifications** — `notify = "errors"` or `"off"`.

## Limitations

- `langmap` is character-based, not physical-keycode-based. Layouts that share
  Latin characters but move them (`de` `z`/`y`, `fr` `a`/`q`) rely on detection
  to pick the right map.
- If several layouts are active and detection is unavailable, only
  non-conflicting pairs can be used safely (`fallback = "unique"`).
- Command-line translation is alias-based; arbitrary Ex commands and search
  patterns are not rewritten.
- Insert-mode literal text is intentionally never translated.
- Windows detection without `im-select.exe` is best-effort (PowerShell reports
  the preferred language, not always the active layout).

## Development

```sh
nvim --headless --clean -u NONE -l tests/test_all.lua
```

For interactive checks (headless `feedkeys` does not apply `langmap`):

```sh
nvim --clean -n -u tests/minimal_init.lua file.txt
```

See [AGENTS.md](AGENTS.md) for architecture, invariants, manual testing and
release guidance.

## License

MIT. See [LICENSE](LICENSE).

Credits:

- [ai/convert-layout](https://github.com/ai/convert-layout) — layout data (MIT).
- [Wansmer/langmapper.nvim](https://github.com/Wansmer/langmapper.nvim) —
  mapping mirroring approach (MIT).
- [mrsobakin/multilayout.nvim](https://github.com/mrsobakin/multilayout.nvim) —
  unique-submap idea (GPL-3.0; no code copied).
