local M = {}

-- Build message lines from an LLM suggestion table
local function suggestion_to_lines(suggestion)
  local scope = suggestion.scope or ""
  local header = scope ~= ""
    and (suggestion.type .. "(" .. scope .. "): " .. suggestion.subject)
    or  (suggestion.type .. ": " .. suggestion.subject)
  local lines = { header }
  if suggestion.bullets and #suggestion.bullets > 0 then
    table.insert(lines, "")
    for _, bullet in ipairs(suggestion.bullets) do
      table.insert(lines, "- " .. bullet)
    end
  end
  table.insert(lines, "")
  return lines
end

-- Async: generate a commit message and prepend it to `buf`
local function generate_and_fill(buf, config)
  local git = require("commit.git")
  local prompt_builder = require("commit.prompt")
  local llm = require("commit.llm")

  local diff, err = git.get_staged_diff(config.exclude_patterns)
  if not diff then
    vim.notify("commit.nvim: " .. (err or "No staged changes"), vim.log.levels.WARN)
    return
  end

  local filenames = git.get_staged_files()
  local git_log = git.get_recent_log(5)
  local prompt = prompt_builder.build(diff, {
    max_diff_chars = config.max_diff_chars,
    prompt_suffix = config.prompt_suffix,
    filenames = filenames,
    git_log = git_log,
  })

  local spinner = require("commit.spinner")
  local spin = spinner.start_notify("Generating commit message")
  spin:start()

  llm.suggest(prompt, config, function(suggestion, llm_err)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      if not suggestion then
        spin:stop()
        vim.notify("commit.nvim: " .. (llm_err or "Unknown error"), vim.log.levels.ERROR)
        return
      end

      -- Stop spinner and show success
      spin:stop("✓ Generated")

      -- Prepend generated message before any existing content
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, suggestion_to_lines(suggestion))

      local wins = vim.fn.win_findbuf(buf)
      if wins and wins[1] then
        vim.api.nvim_win_set_cursor(wins[1], { 1, 0 })
      end
      vim.notify("commit.nvim: message ready — edit and :wq to commit", vim.log.levels.INFO)
    end)
  end)
end

-- Attach <keybind> in `buf` to (re-)generate a commit message.
-- Clears any previously generated lines (before the first comment) then re-fills.
local function attach_keybind(buf, keybind, config)
  vim.keymap.set("n", keybind, function()
    -- Remove previously generated lines (everything before the first '#' comment)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local first_comment = #all_lines + 1
    for i, line in ipairs(all_lines) do
      if line:match("^#") then
        first_comment = i
        break
      end
    end
    if first_comment > 1 then
      vim.api.nvim_buf_set_lines(buf, 0, first_comment - 1, false, {})
    end
    generate_and_fill(buf, config)
  end, {
    buffer = buf,
    noremap = true,
    silent = true,
    desc = "commit.nvim: generate AI commit message",
  })
end

-- Fugitive integration: hooks into COMMIT_EDITMSG buffers opened by vim-fugitive
-- or by `git commit` when $GIT_EDITOR=nvim.
--
-- Config options (under `setup({ fugitive = {...} })`):
--   enabled   (bool)   — must be true to activate (default: false)
--   auto_fill (bool)   — pre-fill on open; false = keybind-only (default: false)
--   keybind   (string) — normal-mode map inside the buffer (default: "<leader>ai")
function M.setup_fugitive(config)
  local fug = config.fugitive or {}
  if not fug.enabled then return end

  local keybind = fug.keybind or "<leader>ai"

  vim.api.nvim_create_augroup("CommitNvimFugitive", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "COMMIT_EDITMSG",
    group = "CommitNvimFugitive",
    callback = function(ev)
      local buf = ev.buf
      attach_keybind(buf, keybind, config)

      -- Guard: only auto-fill once per buffer open
      if fug.auto_fill and not vim.b[buf].commit_nvim_filled then
        vim.b[buf].commit_nvim_filled = true
        generate_and_fill(buf, config)
      end
    end,
  })
end

-- Neogit integration: hooks into NeogitCommitMessage buffers.
--
-- Config options (under `setup({ neogit = {...} })`):
--   enabled   (bool)   — must be true to activate (default: false)
--   auto_fill (bool)   — pre-fill on open; false = keybind-only (default: false)
--   keybind   (string) — normal-mode map inside the buffer (default: "<leader>ai")
function M.setup_neogit(config)
  local ng = config.neogit or {}
  if not ng.enabled then return end

  local keybind = ng.keybind or "<leader>ai"

  vim.api.nvim_create_augroup("CommitNvimNeogit", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "NeogitCommitMessage", "gitcommit" },
    group = "CommitNvimNeogit",
    callback = function(ev)
      local buf = ev.buf
      attach_keybind(buf, keybind, config)
      if ng.auto_fill then
        generate_and_fill(buf, config)
      end
    end,
  })
end

-- LazyGit integration: hooks into COMMIT_EDITMSG buffers opened by LazyGit
--
-- Config options (under `setup({ lazygit = {...} })`):
--   enabled   (bool)   — must be true to activate (default: false)
--   auto_fill (bool)   — pre-fill on open; false = keybind-only (default: false)
--   keybind   (string) — normal-mode map inside the buffer (default: "<leader>ai")
function M.setup_lazygit(config)
  local lg = config.lazygit or {}
  if not lg.enabled then return end

  local keybind = lg.keybind or "<leader>ai"

  vim.api.nvim_create_augroup("CommitNvimLazyGit", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "COMMIT_EDITMSG",
    group = "CommitNvimLazyGit",
    callback = function(ev)
      -- LazyGit opens COMMIT_EDITMSG via $GIT_EDITOR
      local buf = ev.buf
      attach_keybind(buf, keybind, config)

      if lg.auto_fill and not vim.b[buf].commit_nvim_filled then
        vim.b[buf].commit_nvim_filled = true
        generate_and_fill(buf, config)
      end
    end,
  })
end

-- Exported for use by commit_smart in init.lua
M._generate_and_fill = generate_and_fill

return M
