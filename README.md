# 🎯 commit.nvim

*AI-powered conventional commit message generation for Neovim*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.7+-green.svg)](https://neovim.io)

## ✨ Features

- **Smart Analysis** - Analyzes git diff to understand what changed
- **Multi-Provider** - Support for Gemini, OpenAI, Anthropic Claude, and Ollama (local)
- **AI Suggestions** - Generate conventional commit messages from any LLM
- **Interactive Editor** - Review and edit suggestions in a beautiful float window
- **Auto-Staging** - Automatically prompts to stage unstaged changes
- **Conventional Format** - Follows [Conventional Commits](https://www.conventionalcommits.org/) specification
- **Zero Config** - Works out of the box with just an API key (or local Ollama)

## 📦 Installation

```lua
{
  "nxhung2304/commit.nvim",
  config = function()
    require("commit").setup()
  end,
}
```


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

## 🤖 LLM Providers

### 1. Gemini (Default)

Default model: `gemini-2.5-flash`

```lua
require("commit").setup({
  provider = "gemini",
  api_key = vim.env.GEMINI_API_KEY,
  model = "gemini-2.5-flash",  -- or gemini-2.0-flash, gemini-2.0-flash-lite
})
```

**Environment variable:**
```bash
export GEMINI_API_KEY="your-api-key"
```

### 2. OpenAI (GPT-4o / GPT-4o-mini)

Default model: `gpt-4o-mini`

```lua
require("commit").setup({
  provider = "openai",
  api_key = vim.env.OPENAI_API_KEY,
  model = "gpt-4o-mini",  -- or gpt-4o
})
```

**Environment variable:**
```bash
export OPENAI_API_KEY="sk-..."
```

### 3. Anthropic (Claude)

Default model: `claude-3-5-sonnet-20241022`

```lua
require("commit").setup({
  provider = "anthropic",
  api_key = vim.env.ANTHROPIC_API_KEY,
  model = "claude-3-5-sonnet-20241022",
})
```

**Environment variable:**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### 4. Ollama (Local Models)

Run models locally without API keys. Perfect for air-gapped environments or data privacy.

```lua
require("commit").setup({
  provider = "ollama",
  model = "llama3",         -- or gemma2, qwen, mistral, codellama, etc.
  base_url = "http://localhost:11434",  -- Ollama API endpoint
})
```

**Using Ollama from a VPS:**

```lua
require("commit").setup({
  provider = "ollama",
  model = "gemma2:2b",
  base_url = "http://your-vps-ip:11434",  -- Remote Ollama server
})
```

**Setup Ollama:**

1. Install Ollama: https://ollama.ai
2. Pull a model:
   ```bash
   ollama pull llama3
   ```
3. Start Ollama server:
   ```bash
   ollama serve
   ```

**Available models:** `llama3`, `llama2`, `gemma2`, `qwen`, `mistral`, `codellama`, `neural-chat`, and more. See [Ollama models](https://ollama.ai/library).


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
| `<C-y>` | Coppy message to clipboard |
