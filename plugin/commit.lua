vim.api.nvim_create_user_command("Commit", function()
  require("commit").run()
end, { desc = "Generate AI commit message" })

vim.api.nvim_create_user_command("CommitSmart", function()
  require("commit").commit_smart()
end, { desc = "Generate AI commit message in a native commit buffer" })

vim.api.nvim_create_user_command("CommitUndo", function()
  local git = require("commit.git")
  local ui = require("commit.ui")
  ui.confirm("Undo last commit? (staged changes will be preserved)", function()
    local ok, msg = git.undo_last_commit()
    if ok then
      vim.notify("commit.nvim: " .. msg, vim.log.levels.INFO)
    else
      ui.notify_error(msg)
    end
  end, nil)
end, { desc = "Soft-reset HEAD~1 to undo last commit" })
