# physical-keyboard.nvim

Translate the vim motions from your language layout without switching. This plugin allows you to use your native keyboard layout (Russian, German, French, etc.) while working in Neovim, without needing to switch to English/US layout.

## Features

- **Universal layout binding**: Map any keyboard layout to QWERTY/English
- **Multiple layout support**: Use multiple layouts simultaneously (e.g., Russian + German + French)
- **Automatic mapping generation**: Flexible options to auto-generate mappings for:
  - Uppercase letters (`auto_capital`)
  - Modifier combinations (`auto_modifiers`) - Ctrl, Alt, Shift
  - Shifted special characters (`auto_shift_specials`)
  - Number keys (`auto_numbers`)
  - Whitespace characters (`auto_whitespace`)
  - Bracket pairs (`auto_brackets`)
  - Visual mode duplication (`auto_visual_duplicate`)
  - Insert mode duplication (`auto_insert_normal_duplicate`)
  - AltGr combinations for European layouts (`auto_altgr`)
  - Dead keys for Romance languages (`auto_dead_keys`)
  - Accented characters (`auto_accents`)
  - ISO special characters (`auto_iso_specials`)
  - Numeric keypad (`auto_keypad`)
- **Mode-specific mappings**: Configure which Vim modes (normal, visual, insert, etc.) to apply layouts to
- **Exclude insert mode**: Option to prevent layout switching during normal typing (`exclude_insert`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "qFioofa/physical-keyboard.nvim",
  config = function()
    require("physical-keyboard").setup({
      enable = true,
      notify = true,
      active_layouts = { "ru-en" }, -- or {"de-en"}, {"fr-en"}, etc.
      -- Optional: Add custom layouts
      userLayouts = {
        -- your custom layouts here
      },
    })
  end,
}
```

## Default Layouts

The plugin comes with pre-configured layouts:

- **ru-en**: Russian QWERTY to English QWERTY
- **de-en**: German QWERTZ to English QWERTY
- **fr-en**: French AZERTY to English QWERTY

## Configuration

### Basic Setup

```lua
require("physical-keyboard").setup({
  enable = true,           -- Enable/disable the plugin
  notify = true,           -- Enable notifications
  active_layouts = { "ru-en" }, -- Layouts to activate on startup
})
```

### FormMapOptions

When creating a layout, you can specify which automatic mapping options to use:

```lua
local Layout = require("physical-keyboard.layout.Layout")

local my_layout = Layout.new()
my_layout:setName("my-layout")
my_layout:setFormMapOptions({
  "auto_capital",        -- Auto-generate uppercase mappings
  "auto_modifiers",      -- Auto-generate Ctrl/Alt/Shift combinations
  "auto_shift_specials", -- Auto-generate shifted special character mappings
  "auto_altgr",          -- Auto-generate AltGr mappings (for European layouts)
  "auto_dead_keys",      -- Auto-generate dead key combinations
  "auto_accents",        -- Auto-generate accented character mappings
  "auto_iso_specials",   -- Auto-generate ISO special character mappings
})
```

#### Available Options

| Option | Description |
|--------|-------------|
| `all` | Include all options below |
| `auto_capital` | Automatically creates mappings for uppercase letters |
| `auto_modifiers` | Auto-generates Ctrl, Alt, Shift combinations |
| `auto_shift_specials` | Auto-generates shifted special character mappings |
| `auto_numbers` | Auto-generates number key mappings |
| `auto_whitespace` | Auto-generates whitespace/control character mappings |
| `auto_brackets` | Auto-generates bracket pair mappings |
| `auto_visual_duplicate` | Duplicates mappings for visual mode |
| `auto_insert_normal_duplicate` | Duplicates mappings for insert mode |
| `exclude_insert` | Excludes insert mode from mappings |
| `auto_altgr` | Auto-generates AltGr (Right Alt) mappings for European layouts |
| `auto_dead_keys` | Auto-generates dead key combinations (French, Spanish, etc.) |
| `auto_accents` | Auto-generates accented character mappings |
| `auto_iso_specials` | Auto-generates ISO special character mappings (§, °, €, etc.) |
| `auto_noremap_variants` | Creates noremap variants of mappings |
| `auto_keypad` | Auto-generates numeric keypad mappings |

## Commands

| Command | Description |
|---------|-------------|
| `:PhyKeyboard` | Show plugin information |
| `:PhyKeyboardStatus` | Show status of registered layouts |
| `:PhyKeyboardEnable` | Enable the plugin |
| `:PhyKeyboardDisable` | Disable the plugin |
| `:PhyKeyboardEnableLayout <name>` | Enable a specific layout |
| `:PhyKeyboardDisableLayout <name>` | Disable a specific layout |
| `:PhyKeyboardSet <name> <true/false>` | Set layout active state |
| `:PhyKeyboardEcho [on/off]` | Toggle keyboard echo display |
| `:PhyKeyboardEchoMode <mode>` | Set echo display mode |
| `:PhyKeyboardNotify [on/off]` | Toggle notifications |

## Creating Custom Layouts

```lua
local Layout = require("physical-keyboard.layout.Layout")
local g = require("physical-keyboard.const.Globals")

local my_layout = Layout.new()

my_layout:setName("custom-layout")
my_layout:setActive(true)
my_layout:setFormMapOptions({ "auto_capital", "auto_modifiers" })
my_layout:setLayoutName("qwerty")
my_layout:setVimMode("all") -- or {"n", "v", "o"}
my_layout:setOnError(function(message)
  g.VimNotify:e(message)
end)

my_layout:setMap({
  ["й"] = "q",
  ["ц"] = "w",
  ["у"] = "e",
  -- ... more mappings
})

-- Register the layout in your setup
require("physical-keyboard").setup({
  userLayouts = {
    my_layout,
  },
  active_layouts = { "custom-layout" },
})
```

## License

MIT License
