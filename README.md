# 🎯 commit.nvim

*AI-powered conventional commit message generation for Neovim*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.7+-green.svg)](https://neovim.io)

## ✨ Features

- **Smart Analysis** - Analyzes git diff to understand what changed
- **AI Suggestions** - Uses Gemini API to generate conventional commit messages
- **Interactive Editor** - Review and edit suggestions in a beautiful float window
- **Auto-Staging** - Automatically prompts to stage unstaged changes
- **Conventional Format** - Follows [Conventional Commits](https://www.conventionalcommits.org/) specification
- **Zero Config** - Works out of the box with just an API key

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nxhung2304/commit.nvim",
  config = function()
    require("commit").setup({
      api_key = vim.env.GEMINI_API_KEY, -- or set directly
    })
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "nxhung2304/commit.nvim",
  config = function()
    require("commit").setup()
  end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nxhung2304/commit.nvim'
```

## 🔑 Setup

### Get Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikeys)
2. Click "Create API key in new project"
3. Copy the API key

### Configure Neovim

**Option 1: Environment Variable (Recommended)**

```bash
export GEMINI_API_KEY="your-api-key-here"
```

Then in your Neovim config:

```lua
require("commit").setup()  -- auto-reads from env
```

**Option 2: Direct Config**

```lua
require("commit").setup({
  api_key = "AIza...",
})
```

## 🤖 LLM Models

Default: `gemini-2.5-flash` (recommended)

To use a different model:

```lua
require("commit").setup({
  model = "gemini-2.0-flash",  -- or other available models
})
```

Available models:
- `gemini-2.5-flash` - Best quality (default)
- `gemini-2.0-flash` - Fast alternative
- `gemini-2.0-flash-lite` - Lightweight

## ⚙️ Configuration

### Default Configuration

```lua
require("commit").setup({
  -- Gemini API configuration
  provider = "gemini",
  model = "gemini-2.5-flash",
  api_key = nil,           -- auto-reads from GEMINI_API_KEY env

  -- LLM behavior
  temperature = 0,         -- 0 = deterministic, 1 = creative
  max_output_tokens = 1000,

  -- Diff control
  max_diff_chars = 1200,   -- max diff characters sent to LLM
  exclude_patterns = {},   -- file patterns to exclude from diff
                           -- e.g. { "package-lock.json", "*.min.js" }

  -- Prompt customization
  prompt_suffix = nil,     -- extra instructions appended to the prompt
                           -- e.g. "Always write commit messages in English."
})
```

### Example: Exclude lock files and minified assets

```lua
require("commit").setup({
  api_key = vim.env.GEMINI_API_KEY,
  max_diff_chars = 2000,
  exclude_patterns = { "package-lock.json", "yarn.lock", "*.min.js", "*.min.css" },
})
```

### Example: Custom prompt instructions

```lua
require("commit").setup({
  api_key = vim.env.GEMINI_API_KEY,
  prompt_suffix = "Always use past tense. If a JIRA ticket appears in the branch name, prefix the subject with it.",
})
```

## 🔧 Commands

| Command | Description |
|---------|-------------|
| `:Commit` | Generate and commit with AI suggestion |

## ⌨️ Keymaps (inside float window)

| Key | Action |
|-----|--------|
| `<CR>` | Confirm message and commit |
| `<Esc>` | Cancel without committing |
| `<C-r>` | Regenerate a new suggestion from the LLM |

## 🔍 Troubleshooting

### "no API key found"

Set the environment variable before launching Neovim:

```bash
export GEMINI_API_KEY="your-key-here"
```

Or pass it directly in `setup()`:

```lua
require("commit").setup({ api_key = "your-key-here" })
```

### "Not inside a git repository"

Run `:Commit` from a directory tracked by git. Check with:

```bash
git rev-parse --git-dir
```

### "diff truncated" warning

Your diff exceeds `max_diff_chars`. Increase the limit or exclude noisy files:

```lua
require("commit").setup({
  max_diff_chars = 3000,
  exclude_patterns = { "package-lock.json", "yarn.lock" },
})
```

### LLM returns unexpected output

Check `:messages` for raw error output. Verify your API key and network connectivity:

```bash
echo $GEMINI_API_KEY
curl -s "https://generativelanguage.googleapis.com/v1beta/models" \
  -H "x-goog-api-key: $GEMINI_API_KEY" | head -c 200
```

### Neovim help

After installing, access the built-in documentation with:

```vim
:help commit.nvim
```
