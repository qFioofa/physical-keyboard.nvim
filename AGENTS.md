# AGENTS.md — physical-keyboard.nvim

This file is for coding agents **and** for AI assistants that configure the
plugin for a human user. Follow it before editing code or changing somebody's
Neovim configuration.

## Mission

Let a user keep their national keyboard layout in Normal/Visual/Operator-pending
modes. `сшц` must behave like `ciw`, plugin shortcuts must keep working, and
Insert-mode text must never be translated.

The implementation is deliberately thin:

- **`langmap`** does the character translation in C.
- A **mapping mirroring layer** duplicates plugin mappings to the national
  layout.
- A **detection layer** selects the active layout.
- **`cnoreabbrev`** aliases cover the command line, which `langmap` never sees.

No external binary is downloaded, no GPL code is bundled, and no Insert-mode
text is rewritten.

## Golden rules

1. Never translate Insert-mode text.
2. Keep `langremap = off`.
3. Do not bundle GPL code or download binaries without explicit user consent.
4. Do not overwrite a user's config. Make the smallest possible change.
5. X11-only adapters must not run under Wayland/XWayland.
6. A detected English layout must disable translation, not fall back to a
   national layout.
7. Every new behavior needs a test or a documented manual check.
8. Do not commit secrets, API keys, or machine-specific paths.
9. Preserve existing mappings, options, and comments when patching user files.

## Commands

```sh
# Tests (Neovim 0.10+)
nvim --headless --clean -u NONE -l tests/test_all.lua

# Syntax/load check for one module
nvim --headless --clean -u NONE -c "lua assert(loadfile('lua/physical-keyboard/init.lua'))" -c qa

# Formatting (if stylua is available)
stylua lua tests

# Health check inside Neovim
:checkhealth physical-keyboard

# Floating dashboard; Config -> Effective is editable
:PhyKeyboardUI

# Machine-readable environment report (for AI)
:PhyKeyboardDoctor --json
:PhyKeyboardConfig --json
:PhyKeyboardConfigReset
```

There is no package manager, build step, or generated code. Layout data in
`lua/physical-keyboard/layouts/data.lua` is checked in.

## Architecture

| File | Responsibility |
|------|----------------|
| `lua/physical-keyboard/init.lua` | Public API, lifecycle, langmap application, events, statusline, doctor entry point |
| `config.lua` | Defaults, file/env/override loading, validation, notifications |
| `options.lua` | Editable option specs, choices, validation and formatting |
| `overrides.lua` | JSON state override file, atomic writes, reset |
| `langmap.lua` | Build/apply/restore `'langmap'`, escaping, pair counting |
| `layouts/init.lua` | Registry, forward/reverse maps, matching, LCID normalization |
| `layouts/data.lua` | Bundled layout data (English → native) |
| `mappings.lua` | Mirror mappings, keymap API hook, exclusions and extras |
| `which_key.lua` | which-key 3.x/2.x presentation: hide, relative groups, alongside labels |
| `detect/init.lua` | Throttling, remote policy, sync/async detection state |
| `detect/providers.lua` | OS/compositor adapters, selection, probing, async runner |
| `cmdline.lua` | `cnoreabbrev` aliases and runtime add/remove |
| `commands.lua` | All `:PhyKeyboard*` commands |
| `ui/` | Floating dashboard (`:PhyKeyboardUI`); Config → Effective and the picker are editable |
| `echo.lua` | Raw key diagnostic mode |
| `health.lua` | `:checkhealth` report |
| `doctor.lua` | JSON environment report used by AI configuration flows |

## Invariants and gotchas

- `'langmap'` is physical: on Russian ЙЦУКЕН the US `:` position produces `Ж`.
  That is why `:цй` is opened with `Ж ц й Enter`.
- Unescaped `:`, `;`, `,`, `.`, `"`, `|`, `\` in `langmap` cause
  `E357: 'langmap': Matching character missing`. Use `langmap.escape`.
- Only 1:1 character pairs are valid. `ß → ss` is intentionally dropped.
- Uppercase pairs are generated automatically for cased letters.
- `langmap` does not apply to literal Insert mode or the command line.
- `langremap` must stay off, otherwise mirrored mappings are translated again.
- `<Plug>`, `<Sid>`, `<Snr>` mappings are never mirrored.
- Detection runs on `FocusGained`, `VimResume`, and `InsertLeave` by default and
  is throttled. Do not add a polling loop.
- `InsertLeave` can fire often; detection is asynchronous by default
  (`detect.async = true`) and must not block the editor.
- On SSH the local layout is irrelevant. `detect.remote = "auto"` disables
  detection; use `active_layouts` or force a layout.
- UI edits are stored in a JSON override file under `stdpath("state")`; never
  rewrite the user's Lua config or `setup()` table.
- `overrides = false` ignores that file for the whole session.
- Detection matches the raw OS string against **all** bundled layouts and adds
  the discovered layout at runtime.
- `fallback = "unique"` keeps only non-conflicting pairs when the layout is
  unknown. With one active layout, a hard fallback such as `"ru"` is usually
  better.

## AI configuration playbook

Use this when the user says anything like “set up physical-keyboard for me”,
“I use a Russian layout”, “my shortcuts don't work in нормальном режиме”, or
“configure it for macOS/Windows/niri”.

### Step 0 — collect the minimum context

Ask only what you cannot infer:

1. Operating system and desktop/session: X11, Wayland (which compositor),
   macOS, Windows, WSL.
2. Primary language layout(s), e.g. `ru`, `de`, `fr`, `ru+de`.
3. Does the user switch layouts while working, or always keep one layout?
4. Is Neovim local or remote over SSH?
5. Which plugin manager is in use (lazy.nvim, packer, native `packadd`)?
6. Are there shortcuts that must **not** be mirrored (e.g. Telescope leader
   mappings)?
7. Does the user want a statusline indicator or a toggle key?

If the user is unsure, assume: local Neovim, lazy.nvim, one national layout,
automatic detection on, `fallback = "unique"`.

### Request routing

| User says | Action |
|-----------|--------|
| “I use Russian/German/…” | Set `active_layouts` to that layout; keep detection on. |
| “I switch between RU and EN” | Keep `detect.enabled = true`; this is the default. |
| “I only use one layout” | `detect.enabled = false`, `fallback = "<id>"`. |
| “I'm on niri/sway/Hyprland” | No install; the built-in adapter handles it. |
| “I'm on X11” | Offer to install `xkb-switch`; `setxkbmap` is a fallback. |
| “I'm on macOS” | Offer to install `im-select`; `defaults` is best-effort. |
| “I'm on Windows” | Offer to install `im-select.exe`; PowerShell is best-effort. |
| “I use SSH / a remote server” | Keep `detect.remote = "auto"`; set `active_layouts`/`fallback`. |
| “My plugin shortcuts don't work” | Check `mappings.hack_keymap`, run `:PhyKeyboardMappings`, add exclusions only if needed. |
| “I don't want mirroring” | `mappings.enabled = false`. |
| “I want a statusline indicator” | Add `statusline()` to lualine/statusline; see below. |
| “I want a toggle key” | Set `toggle_key = "<leader>tk"` or use `:PhyKeyboardToggle`. |
| “The plugin does nothing” | Check that `setup()`/`opts` is actually called. |

### Prompt template for an AI assistant

Use or adapt this when the user asks for help:

```text
You are configuring physical-keyboard.nvim. First ask for the OS, desktop or
Wayland compositor, national layout(s), whether the user switches layouts,
whether Neovim is local or over SSH, the plugin manager, and any shortcuts that
must not be mirrored. Then run :PhyKeyboardDoctor --json and use its
session/detection/config fields. Choose the smallest setup table, patch only the
plugin's opts or setup table, and preserve the user's existing configuration.
Verify with :PhyKeyboardStatus, :PhyKeyboardDetect, :PhyKeyboardConfig --json and
:checkhealth physical-keyboard. Explain the physical ':' position caveat and
how to roll back. Do not install external tools without explicit permission.
```

### Step 1 — inspect the environment

Ask the user to run, or run yourself:

```vim
:PhyKeyboardDoctor --json
```

Equivalent headless form:

```sh
nvim --headless \
  -c 'lua print(vim.json.encode(require("physical-keyboard").doctor({ probe = true })))' \
  -c qa 2>&1
```

Read these fields:

- `session.os`, `session.session_type`, `session.desktop`, `session.remote`
- `detection.probes` — which adapters returned a layout
- `detection.environment.executables` — which helper binaries exist
- `config.source.file` and `config.file` — where settings are loaded from
- `recommendations` — already generated hints
- `layouts.active` and `layouts.current`

If the module cannot be loaded, the plugin is not installed or not on
`runtimepath`. Stop and ask the user to install it; do not invent a patch.

### Step 2 — choose the detection strategy

| Environment | Recommended setup |
|-------------|------------------|
| Linux + niri / sway / Hyprland | Built-in adapter; no install. Keep detection on. |
| Linux + GNOME / KDE / Plasma | Built-in `gsettings` / `qdbus`; no install. |
| Linux + X11 | Install `xkb-switch` (ask first). `setxkbmap -query` is a fallback. |
| Linux + unknown Wayland compositor | Ask which compositor; if unsupported, disable detection and use `fallback`. |
| macOS | Install `im-select` (ask first). `defaults` is best-effort. |
| Windows | Install `im-select.exe` (ask first). PowerShell is best-effort. |
| SSH / remote Neovim | Keep `detect.remote = "auto"` (detection off) and set `active_layouts`; or force a layout. |
| No detection possible | Use one active layout with `fallback = "ru"` (or the user's layout). |

Do not install packages without explicit permission. Show the exact command
and explain why it is needed. Common examples:

```sh
# Debian / Ubuntu
sudo apt install xkb-switch
# Arch
sudo pacman -S xkb-switch
# macOS
brew install im-select
```

For Windows, download `im-select.exe` from
https://github.com/daipeihust/im-select and put it on `PATH`.

### Step 3 — generate the configuration

Prefer plugin-manager options over rewriting `init.lua`.

**lazy.nvim (recommended):**

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
automatically.

**Native / manual:**

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
})
```

**External file (when the user wants settings outside `init.lua`):**

```lua
require("physical-keyboard").setup({
  config_file = true, -- ~/.config/nvim/physical-keyboard.lua
})
```

Then edit the file with `:PhyKeyboardEditConfig` and reload with
`:PhyKeyboardReload`. A custom path is also accepted:
`config_file = "~/.config/nvim/pkb.lua"`.

**Quick experiments:**

```sh
PKB_LAYOUT=de nvim      # force one layout for this run
PKB_DISABLE=1 nvim      # temporarily disable the plugin
PKB_DEBUG=1 nvim        # echo keyboard + all notifications
```

### Step 4 — apply safely

1. Find the user's plugin spec or `setup()` call. Search for
   `physical-keyboard` and for the plugin directory name.
2. Patch only the `opts`/`setup` table. Do not reformat the file.
3. Preserve comments, unrelated plugins, and existing keymaps.
4. If the user has no config, add a minimal lazy.nvim spec.
5. Do not add `active_layouts` entries the user did not ask for.
6. Do not disable Insert-mode behavior; it is intentionally untouched.
7. If the user wants an external file, set `config_file = true` or
   `PKB_CONFIG`, then create the file from `:PhyKeyboardEditConfig`.

### Step 5 — verify

Run or ask the user to run:

```vim
:PhyKeyboardStatus
:PhyKeyboardDetect
:PhyKeyboardConfig --json
:checkhealth physical-keyboard
:PhyKeyboardMappings
```

Expected results:

- `Detection` shows a provider and the user's layout.
- `langmap pairs` is greater than zero for a national layout.
- `Mirrored mappings` grows after plugins load.
- No config warnings from `:checkhealth`.
- `:PhyKeyboardStatus` shows `Current layout: English` when the OS layout is US.

Manual smoke test for a Russian layout:

1. Put the cursor on a word in Normal mode.
2. Type `сшц` (physical `ciw`).
3. The word should be selected/changed as with `ciw`.
4. Type `Ж ц й Enter` to save and quit (`:` `w` `q`).
5. Enter Insert mode and type `привет`; it must stay `привет`.

If the user cannot test interactively, at least verify `:PhyKeyboardStatus`,
`:PhyKeyboardDetect`, and `:PhyKeyboardConfig --json`.

### Step 6 — explain the result

Tell the user:

- which layout(s) are active and which detection provider was selected;
- that Insert mode is untouched;
- why `:` is opened with the physical US position (`Ж` on ЙЦУКЕН);
- how to toggle (`:PhyKeyboardToggle`, `:PhyKeyboardEnable/Disable`, or
  `toggle_key`);
- how to roll back (remove `opts`, set `enable = false`, or `PKB_DISABLE=1`);
- any optional tool they still need to install.

Answer in the user's language.

## Configuration recipes

### Russian only, no detection

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { enabled = false },
  fallback = "ru",
})
```

### Russian + English, automatic switching

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { enabled = true },
  fallback = "unique",
})
```

English is handled by detection: when the OS reports a US layout, `langmap` is
cleared automatically.

### Multilingual

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru", "de", "fr" },
  fallback = "unique",
})
```

### Mirrored mappings disabled (built-in motions only)

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  mappings = { enabled = false },
})
```

### Exclude specific mappings

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  mappings = {
    exclude = { "<Leader>f", "<C%-" },
  },
})
```

Entries are compared to the raw LHS and also used as Lua patterns.

### Custom layout

```lua
require("physical-keyboard").setup({
  active_layouts = { "my" },
  userLayouts = {
    my = {
      title = "My layout",
      names = { "my", "My Layout" },
      map = {
        ["q"] = "й",
        ["w"] = "ц",
      },
    },
  },
})
```

The map is English character → native character. Uppercase pairs are generated.

### Command-line aliases

```lua
require("physical-keyboard").setup({
  cmdline = {
    aliases = { "tabnew", "resize" }, -- extra English commands
    extra = { ["цц"] = "w" },         -- explicit native → English
  },
})
```

Runtime: `:PhyKeyboardAliases add цц w`, `:PhyKeyboardAliases remove цц`,
`:PhyKeyboardAliases`.

### Toggle key and notifications

```lua
require("physical-keyboard").setup({
  toggle_key = "<leader>tk",
  notify = "errors", -- "all" | "errors" | "off"
})
```

### Statusline

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

Options: `{ uppercase = false, english = "ENG", unknown = "--", prefix = "", suffix = "" }`.

### Remote / SSH

```lua
require("physical-keyboard").setup({
  active_layouts = { "ru" },
  detect = { remote = "auto" }, -- detection off over SSH
  fallback = "ru",
})
```

### Excluded/extra mapping variants

```lua
mappings = {
  exclude = { "<Leader>f" },
  extra = { ["<Leader>zz"] = "<Leader>ZZ" },
}
```

`mappings.extra` adds an explicit native variant for an existing English LHS.

## Configuration reference

Top level: `config_file`, `env`, `enable`, `notify`, `active_layouts`,
`fallback`, `toggle_key`, `detect`, `langmap`, `mappings`, `which_key`,
`cmdline`, `echo`.  `env = false` ignores `PKB_*` variables (including
`PKB_CONFIG`).

`detect`: `enabled`, `provider`, `providers`, `remote`, `min_interval`,
`timeout`, `events`, `async`, `on_change`.

`mappings`: `enabled`, `hack_keymap`, `automapping`, `modes`, `exclude`,
`extra`.  `modes` defaults to `n,x,s,o`; add `i`, `c`, or `t` when the user
explicitly wants those mappings mirrored.

`which_key`: `enabled`, `display`, `relative_group`, `alongside`, `separator`.
`display = nil`/`"hide"` hides mirrors; precedence is `alongside` →
`relative_group` → `hide`.  A translated prefix group replaces the original
group label; which-key cannot place a translated key inside the original group.

`cmdline`: `enabled`, `aliases`, `extra`.

`echo`: `enabled`, `mode`.

Notifications: `true` → `"all"`, `false` → `"errors"`, `"off"` silences
everything, `"errors"` shows warnings/errors only.

## Verification checklist for code changes

```sh
nvim --headless --clean -u NONE -l tests/test_all.lua
```

Then:

- load every module with `loadfile`;
- run `:checkhealth physical-keyboard`;
- run `:PhyKeyboardDoctor --json` and confirm it is valid JSON;
- test `:PhyKeyboardEnable`, `:PhyKeyboardDisable`, `:PhyKeyboardToggle`;
- test an English layout response and a remote session if the change touches
  detection;
- confirm no `E357` when applying `langmap`;
- confirm Insert-mode text is unchanged.

## Adding a layout

1. Add an entry to `lua/physical-keyboard/layouts/data.lua`:
   `title`, `names`, `map` (English → native).
2. Keep only 1:1 character pairs; uppercase is generated.
3. Add the Windows LCID to `LCID` in `layouts/init.lua` if applicable.
4. Add names that the OS adapter may report (e.g. `"Russian"`, `"de"`).
5. Add a test in `tests/test_all.lua` and update the layout table in README and
   help files.

## Adding a detection provider

1. Add a table to `providers` in `detect/providers.lua`:
   `{ name = "...", get = function() ... end }`.
2. Guard the platform and required executable; return `nil` when unavailable.
3. Use `run({...})` (array form, no shell) so the async coroutine runner can
   intercept it.
4. Return a raw layout string; matching is done by `layouts.match`.
5. Document the provider in README/help and add it to the doctor’s tool list.
6. Add tests for selection and, where possible, the parser.

## Manual/interactive testing

Headless `nvim_input`/`feedkeys` does **not** apply `langmap`. Use a pty:

```python
import pexpect

child = pexpect.spawn(
    "nvim",
    ["--clean", "-n", "-u", "tests/minimal_init.lua", "file.txt"],
    env={"TERM": "xterm-256color", **os.environ},
)
```

Use `ZZ` to save and quit; sending `:wq\r` through the terminal is unreliable.
For raw key inspection use `:PhyKeyboardEcho on` and
`:PhyKeyboardEchoMode debug`.

## License and provenance

MIT. Layout data is from `ai/convert-layout` (MIT). Mapping mirroring is
inspired by `Wansmer/langmapper.nvim` (MIT). The unique-submap idea comes from
`mrsobakin/multilayout.nvim` (GPL-3.0); no GPL code may be copied.
