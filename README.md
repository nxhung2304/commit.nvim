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
  api_key = nil,  -- auto-reads from GEMINI_API_KEY env
  
  -- LLM behavior
  temperature = 0,       -- 0 = deterministic, 1 = creative
  max_output_tokens = 1000,
})
```

## 🔧 Commands

| Command | Description |
|---------|-------------|
| `:Commit` | Generate and commit with AI suggestion |
