vim.api.nvim_create_user_command("Commit", function()
  require("commit").run()
end, { desc = "Generate AI commit message" })
