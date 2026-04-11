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
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  local api_key = config.api_key or vim.env.GEMINI_API_KEY or os.getenv("GEMINI_API_KEY")
  if not api_key then
    vim.notify(
      "commit.nvim: no API key found. Set GEMINI_API_KEY or pass api_key to setup()",
      vim.log.levels.ERROR
    )
  end
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
  local prompt, truncated = prompt_builder.build(diff, {
    max_diff_chars = config.max_diff_chars,
    prompt_suffix = config.prompt_suffix,
    filenames = filenames,
    git_log = git_log,
  })

  -- 4. Generate suggestion; defined as local to allow <C-r> regeneration
  local function generate()
    ui.notify_loading()
    llm.suggest(prompt, config, function(suggestion, llm_err)
      vim.schedule(function()
        if not suggestion then
          ui.notify_error(llm_err or "Unknown error")
          return
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
        end, generate)
      end)
    end)
  end

  generate()
end

return M
