# lazy-watson

A Neovim plugin that displays inline translation values for [Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) `m.keyName()` calls. See your translations directly in your code without switching files.

![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)

## Features

- **Inline Preview**: Shows translation values as virtual text after `m.keyName()` calls
- **Hover Preview**: Displays all locale translations in a floating window on cursor hold
- **Missing Locale Indicator**: Highlights which locales are missing translations inline
- **Live Updates**: Watches translation files and updates automatically on changes
- **Locale Switching**: Quickly switch between locales to preview different translations

## Inspiration

This plugin brings the functionality of these excellent tools to Neovim:

- [**elementary-watson**](https://github.com/romerramos/elementary-watson) - VS Code extension that displays inline translation values for i18n method calls
- [**Sherlock (inlang IDE Extension)**](https://inlang.com/m/r7kp499g/app-inlang-ideExtension) - VS Code extension for visualizing, editing, and linting translated strings with inline decorations and hover support

Built specifically for projects using [Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) - the i18n library that compiles messages into tree-shakable functions.

## Related Projects

### [lazyi18n](https://github.com/strehk/lazyi18n)

A Terminal UI for i18n management that pairs perfectly with lazy-watson. While lazy-watson lets you *see* your translations inline, lazyi18n lets you *edit* them in a beautiful TUI.

```lua
-- Add a keybinding to edit the translation under cursor
{
  "<leader>we",
  function()
    local key = require("lazy-watson").get_key_at_cursor()
    if key then
      vim.cmd("terminal lazyi18n tui --edit " .. key)
    end
  end,
  desc = "Edit translation key",
}
```

## Requirements

- Neovim >= 0.9.0
- An [inlang](https://inlang.com) project with `project.inlang/settings.json`
- [Paraglide JS](https://inlang.com/m/gerre34r/library-inlang-paraglideJs) installed in your project

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "strehk/lazy-watson",
  ft = { "javascript", "typescript", "svelte", "javascriptreact", "typescriptreact" },
  opts = {},
  keys = {
    { "<leader>wt", function() require("lazy-watson").toggle() end, desc = "Toggle Watson preview" },
    { "<leader>wl", function() require("lazy-watson").select_locale() end, desc = "Select locale" },
    { "<leader>wr", function() require("lazy-watson").refresh() end, desc = "Refresh translations" },
    { "<leader>wh", function() require("lazy-watson").show_hover() end, desc = "Show hover preview" },
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "strehk/lazy-watson",
  config = function()
    require("lazy-watson").setup()
  end,
}
```

## Configuration

```lua
require("lazy-watson").setup({
  enabled = true,
  debounce_ms = 150,

  virtual_text = {
    prefix = " -> ",              -- Prefix before translation
    hl_group = "Comment",         -- Highlight group for translations
    hl_missing_key = "DiagnosticError",    -- Highlight for missing keys
    hl_missing_locale = "DiagnosticWarn",  -- Highlight for missing locale file
    max_length = 50,              -- Max translation length before truncation
    show_missing = true,          -- Show missing locale indicator
    missing_prefix = "  X ",      -- Prefix for missing locales
    hl_missing_locales = "DiagnosticError", -- Highlight for missing locale codes
  },

  hover = {
    enabled = true,               -- Enable hover preview on CursorHold
    delay = 300,                  -- Delay before showing hover (updatetime)
  },

  project_pattern = "project.inlang/settings.json",
})
```

## Usage

### Inline Preview

When you open a JavaScript/TypeScript file with Paraglide message calls, translations appear automatically:

```typescript
const greeting = m.hello()  -> "Hello, World!"
const button = m.submit()   -> "Submit"  X de, fr
```

The `X de, fr` indicates the key is missing in German and French locales.

### Hover Preview

Place your cursor on a `m.keyName()` call and wait (or press your hover keybinding) to see all translations:

```
┌─────────────────────────────┐
│  hello                      │
│ ─────────────────────────── │
│  en: "Hello, World!"        │
│  de: "Hallo, Welt!"         │
│  fr: ⚠ [missing]            │
└─────────────────────────────┘
```

### Commands

| Function | Description |
|----------|-------------|
| `require("lazy-watson").toggle()` | Toggle preview on/off |
| `require("lazy-watson").select_locale()` | Open locale picker |
| `require("lazy-watson").refresh()` | Reload all translations |
| `require("lazy-watson").show_hover()` | Show hover preview at cursor |
| `require("lazy-watson").get_key_at_cursor()` | Get translation key at cursor |

## Supported Patterns

The plugin recognizes these Paraglide patterns:

```typescript
// Standard message calls
m.hello()
m.auth_loginButton()

// With arguments
m.greeting({ name: "World" })

// Bracket notation for special keys
m["nested.key"]()
m['special-key']()
```

## Project Structure

Your project should have an inlang setup like:

```
your-project/
├── project.inlang/
│   └── settings.json
├── messages/
│   ├── en.json
│   ├── de.json
│   └── fr.json
└── src/
    └── ...
```

## License

MIT
