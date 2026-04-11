# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**commit.nvim** is a Neovim plugin that generates AI-powered conventional commit messages using the Gemini API. Users run the `:Commit` command to analyze staged changes and get LLM-suggested commit messages that follow the Conventional Commits specification.

## Architecture

The plugin follows a clear layered architecture:

```
Entry Point (plugin/commit.lua)
    ↓
Orchestrator (lua/commit/init.lua)
    ├─→ Git Layer (lua/commit/git.lua)
    ├─→ LLM Layer (lua/commit/llm/)
    │   └─→ Gemini Provider (lua/commit/llm/gemini.lua)
    ├─→ Prompt Builder (lua/commit/prompt.lua)
    └─→ UI Layer (lua/commit/ui.lua)
```

### Core Flow

1. **Entry**: `:Commit` command registered in `plugin/commit.lua`
2. **Orchestration** (`lua/commit/init.lua`):
   - Manages configuration
   - Coordinates the main workflow: get diff → build prompt → call LLM → show UI → commit
3. **Git Operations** (`lua/commit/git.lua`):
   - `get_staged_diff()` - returns diff or nil
   - `has_unstaged_changes()` - check for uncommitted work
   - `stage_all()` - stage all changes if user opts in
   - `do_commit(message)` - execute `git commit`
4. **LLM Integration** (`lua/commit/llm/`):
   - **Provider abstraction** (`init.lua`) - allows swapping providers (currently only Gemini)
   - **Gemini provider** (`gemini.lua`) - calls Gemini API via curl, parses JSON response
5. **Prompt Building** (`lua/commit/prompt.lua`):
   - Takes git diff as input
   - Truncates to ~1200 chars
   - Builds prompt with instructions for conventional commits format
   - Instructs LLM to return JSON with `{type, subject, bullets}`
6. **UI** (`lua/commit/ui.lua`):
   - Centered floating window with rounded border
   - Renders formatted suggestion (type: subject + bullets)
   - Keymaps: `<CR>` to confirm, `<Esc>` to cancel
   - Auto-enters insert mode for user editing

### Key Design Decisions

- **Async LLM calls**: Uses `vim.fn.jobstart()` + `vim.schedule()` to avoid blocking the editor
- **Provider abstraction**: LLM layer allows plugging in different providers (e.g., Claude, OpenAI) without changing core flow
- **Fallback parsing**: If Gemini returns incomplete JSON, the parser attempts regex extraction for `type` and `subject` fields
- **Git safety**: Uses git commands directly; escapes shell quotes in commit messages

## Development

### Prerequisites

- Neovim 0.7+ with Lua support
- Git installed
- Gemini API key (set via `GEMINI_API_KEY` env var or plugin config)

### Running the Plugin Locally

For testing in Neovim:

1. Add to your package manager config (lazy.nvim example):
   ```lua
   {
     "nxhung2304/commit.nvim",
     config = function()
       require("commit").setup({ api_key = vim.env.GEMINI_API_KEY })
     end,
   }
   ```

2. Or add the directory to your `runtimepath`:
   ```vim
   set runtimepath+=~/path/to/commit.nvim
   ```

3. Inside Neovim, run `:Commit` to test

### Modifying the Plugin

- **Add a new provider**: Create `lua/commit/llm/provider_name.lua` with a `suggest(prompt, config, callback)` function and register it in `lua/commit/llm/init.lua`
- **Change prompt template**: Edit `lua/commit/prompt.lua` to adjust the prompt instructions or diff truncation
- **Adjust UI layout**: Modify calculations in `lua/commit/ui.lua` (window size, positioning, borders)
- **Extend configuration**: Add new config options in `lua/commit/init.lua`, pass them through the layers

### Debugging

- Check Neovim logs: `:messages`
- Verify API key: `echo $GEMINI_API_KEY`
- Test git operations: `:lua require("commit.git").get_staged_diff()`
- Watch async curl calls: Monitor temp files created in vim temp directory
- Test Gemini response parsing: Manually call `lua/commit/llm/gemini.lua` with sample response

## Configuration

Default config in `lua/commit/init.lua`:

```lua
{
  provider = "gemini",           -- LLM provider
  model = "gemini-2.5-flash",    -- Gemini model to use
  api_key = nil,                 -- Read from GEMINI_API_KEY env if nil
  temperature = 0,               -- Deterministic output
  max_output_tokens = 1000,      -- Token limit for response
}
```

## Testing Notes

- No automated test framework currently set up
- Manual testing via `:Commit` in Neovim is the primary validation method
- Test with various diff sizes and types of changes
- Verify conventional commit format output (type: subject + bullets)

## Type System

- Lua language server configured in `.luarc.json` targets LuaJIT with `vim` global available
- Use `vim` API functions directly (e.g., `vim.fn.system`, `vim.api.nvim_*`)
