local M = {}

local config = {
  provider = "gemini",
  model = "gemini-2.5-flash",
  api_key = nil,
  temperature = 0,
  max_output_tokens = 1000,
  max_diff_chars = 8000,
  exclude_patterns = {},
  prompt_suffix = nil,
  candidate_count = 1,
  ui = {
    border = "rounded",
    width = nil,
    position = "center",
  },
  fugitive = {
    enabled = false,
    auto_fill = false,
    keybind = "<leader>ai",
  },
  neogit = {
    enabled = false,
    auto_fill = false,
    keybind = "<leader>ai",
  },
  lazygit = {
    enabled = false,
    auto_fill = false,
    keybind = "<leader>ai",
  },
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Validate API key based on provider
  local provider = config.provider or "gemini"
  local api_key_env = {
    gemini = "GEMINI_API_KEY",
    anthropic = "ANTHROPIC_API_KEY",
    openai = "OPENAI_API_KEY",
    ollama = nil, -- Ollama doesn't need an API key
  }

  local required_env = api_key_env[provider]
  if required_env then
    local api_key = config.api_key or vim.env[required_env] or os.getenv(required_env)
    if not api_key then
      vim.notify(
        "commit.nvim: no API key found. Set " .. required_env .. " or pass api_key to setup()",
        vim.log.levels.ERROR
      )
    end
  end

  local integrations = require("commit.integrations")
  integrations.setup_fugitive(config)
  integrations.setup_neogit(config)
  integrations.setup_lazygit(config)
end

function M.run()
  local git = require("commit.git")
  local prompt_builder = require("commit.prompt")
  local llm = require("commit.llm")
  local ui = require("commit.ui")

  -- 1. Get staged diff (respects exclude_patterns)
  local diff, err = git.get_staged_diff(config.exclude_patterns)
  if err then
    ui.notify_error(err)
    return
  end

  if not diff then
    if not git.has_unstaged_changes() then
      ui.notify_error("Nothing to commit")
      return
    end

    ui.confirm("No staged changes. Stage all?", function()
      git.stage_all()
      M.run()
    end)
    return
  end

  -- 2. Gather context: staged filenames + recent git log
  local filenames = git.get_staged_files()
  local git_log = git.get_recent_log(5)

  -- 3. Build prompt
  local prompt, _ = prompt_builder.build(diff, {
    max_diff_chars = config.max_diff_chars,
    prompt_suffix = config.prompt_suffix,
    filenames = filenames,
    git_log = git_log,
  })

  -- 4. Generate suggestion; defined as local to allow <C-r> regeneration
  local function generate()
    ui.notify_loading()
    local history = require("commit.history")
    history.reset_cursor()

    local use_multi = config.candidate_count and config.candidate_count > 1
    local llm_func = use_multi and llm.suggest_multi or llm.suggest

    llm_func(prompt, config, function(result, llm_err)
      vim.schedule(function()
        if not result then
          ui.error_modal(llm_err or "Unknown error", generate)
          return
        end

        -- Handle both single suggestion and array of suggestions
        local suggestion, suggestions_array
        if use_multi then
          suggestions_array = result
          suggestion = suggestions_array[1]
        else
          suggestion = result
          suggestions_array = { result }
        end

        ui.open(suggestion, function(message)
          if message == "" then
            ui.notify_error("Empty commit message, aborted")
            return
          end
          local ok, output = git.do_commit(message)
          if ok then
            vim.notify("commit.nvim: " .. output:gsub("%s+$", ""), vim.log.levels.INFO)
          else
            ui.notify_error(output)
          end
        end, generate, { ui_config = config.ui, suggestions = suggestions_array })
      end)
    end)
  end

  generate()
end

-- :CommitSmart — opens a gitcommit buffer pre-filled with an AI message.
-- The user edits inline; :wq commits, :q! aborts.
-- Fallback for users without vim-fugitive or Neogit.
function M.commit_smart()
  local git = require("commit.git")
  local ui = require("commit.ui")
  local integrations = require("commit.integrations")

  -- 1. Ensure staged changes exist
  local diff, err = git.get_staged_diff(config.exclude_patterns)
  if err then
    ui.notify_error(err)
    return
  end

  if not diff then
    if not git.has_unstaged_changes() then
      ui.notify_error("Nothing to commit")
      return
    end
    ui.confirm("No staged changes. Stage all?", function()
      git.stage_all()
      M.commit_smart()
    end)
    return
  end

  -- 2. Open a gitcommit buffer in a new split, pre-populated with the git status template
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "gitcommit"
  vim.bo[buf].bufhidden = "wipe"

  local status_out = vim.fn.system({ "git", "status" })
  local template = {
    "",
    "# Please enter the commit message for your changes.",
    "# Lines starting with '#' will be ignored.",
    "# An empty message aborts the commit.",
    "#",
  }
  for line in status_out:gmatch("[^\n]+") do
    table.insert(template, "# " .. line)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, template)

  -- Open in a new split (safe — never clobbers unsaved work)
  vim.cmd("split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- 3. :wq commits; :q! discards (bufhidden=wipe handles cleanup)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local msg_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      -- Strip comment lines
      local filtered = vim.tbl_filter(function(l) return not l:match("^#") end, msg_lines)
      -- Trim leading/trailing blank lines
      while #filtered > 0 and filtered[1]:match("^%s*$") do table.remove(filtered, 1) end
      while #filtered > 0 and filtered[#filtered]:match("^%s*$") do table.remove(filtered) end

      vim.bo[buf].modified = false

      local msg = table.concat(filtered, "\n")
      if msg == "" then
        vim.notify("commit.nvim: empty message, commit aborted", vim.log.levels.WARN)
        vim.api.nvim_win_close(win, true)
        return
      end

      local ok, output = git.do_commit(msg)
      if ok then
        vim.notify("commit.nvim: " .. output:gsub("%s+$", ""), vim.log.levels.INFO)
        vim.api.nvim_win_close(win, true)
      else
        ui.notify_error(output)
      end
    end,
  })

  -- 4. Generate and prepend the AI message asynchronously
  integrations._generate_and_fill(buf, config)
end

return M
