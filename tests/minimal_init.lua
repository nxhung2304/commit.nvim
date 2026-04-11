-- Minimal Neovim init used by plenary test runner.
-- Adds the plugin root and plenary to the runtime path.
--
-- Usage:
--   nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua'}"
--
-- Set PLENARY_DIR to override the default plenary install path.

local plenary_dir = os.getenv("PLENARY_DIR")
  or (vim.fn.stdpath("data") .. "/site/pack/vendor/start/plenary.nvim")

vim.opt.rtp:prepend(plenary_dir)
vim.opt.rtp:prepend(".")

vim.cmd("runtime plugin/plenary.vim")
