local M = {}

local config = {
  provider = "gemini",
  model = "gemini-2.5-flash",
  api_key = nil, -- fallback: đọc từ GEMINI_API_KEY env
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.run()
  local git = require("commit.git")
  local prompt_builder = require("commit.prompt")
  local llm = require("commit.llm")
  local ui = require("commit.ui")

  -- 1. Lấy staged diff
  local diff, err = git.get_staged_diff()
  if err then
    ui.notify_error(err)
    return
  end

  if not diff then
    if not git.has_unstaged_changes() then
      ui.notify_error("Nothing to commit")
      return
    end

    vim.api.nvim_echo({ { "No staged changes. Stage all? [y/N] ", "WarningMsg" } }, false, {})
    local ok, char = pcall(vim.fn.getchar)
    if ok and (char == 121 or char == 89) then -- 'y' or 'Y'
      git.stage_all()
      M.run()
    end
    return
  end

  -- 2. Gọi LLM async
  ui.notify_loading()
  local prompt = prompt_builder.build(diff)

  llm.suggest(prompt, config, function(suggestion, llm_err)
    -- callback chạy trong async context, cần schedule về main loop
    vim.schedule(function()
      if not suggestion then
        ui.notify_error(llm_err or "Unknown error")
        return
      end

      -- 3. Mở UI cho user xác nhận / chỉnh sửa
      ui.open(suggestion, function(message)
        if message == "" then
          ui.notify_error("Empty commit message, aborted")
          return
        end

        -- 4. Thực hiện commit
        local ok, output = git.do_commit(message)
        if ok then
          vim.notify("commit.nvim: " .. output:gsub("%s+$", ""), vim.log.levels.INFO)
        else
          ui.notify_error(output)
        end
      end)
    end)
  end)
end

return M
