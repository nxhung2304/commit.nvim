local M = {}

local function format_message(suggestion)
  local lines = {}

  -- Subject line
  table.insert(lines, suggestion.type .. ": " .. suggestion.subject)

  -- Bullets
  if suggestion.bullets and #suggestion.bullets > 0 then
    table.insert(lines, "")
    for _, bullet in ipairs(suggestion.bullets) do
      table.insert(lines, "- " .. bullet)
    end
  end

  return table.concat(lines, "\n")
end

function M.open(suggestion, on_confirm, on_regenerate)
  local message = format_message(suggestion)
  local lines = vim.split(message, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "gitcommit"
  vim.bo[buf].bufhidden = "wipe"

  -- Calculate size based on content
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, #line)
  end
  local width = math.max(1, math.min(math.max(max_width + 4, 60), vim.o.columns - 4))
  -- +2 for the separator and hint lines rendered via virt_lines at the bottom
  local height = math.max(1, math.min(#lines + 2, vim.o.lines - 4))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " commit.nvim ",
    title_pos = "center",
  })

  vim.wo[win].wrap = true

  -- Bottom hint via virtual lines below the last content line
  local hint = on_regenerate
    and " <CR> confirm · <C-r> regenerate · <Esc> cancel"
    or " <CR> confirm · <Esc> cancel"
  vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("commit_hint"), #lines - 1, 0, {
    virt_lines = {
      { { string.rep("─", width - 2), "Comment" } },
      { { hint, "Comment" } },
    },
  })

  -- Keymaps
  local function confirm()
    local final_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local final_msg = table.concat(final_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    vim.api.nvim_win_close(win, true)
    on_confirm(final_msg)
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", confirm, opts)
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    vim.notify("commit.nvim: cancelled", vim.log.levels.INFO)
  end, opts)

  if on_regenerate then
    local function regenerate()
      vim.api.nvim_win_close(win, true)
      on_regenerate()
    end
    vim.keymap.set("n", "<C-r>", regenerate, opts)
    vim.keymap.set("i", "<C-r>", regenerate, opts)
  end

  -- Enter insert mode so the user can edit immediately
  vim.cmd("startinsert!")
end

function M.confirm(message, on_yes, on_no)
  local lines = { message, "", "  [y] Yes    [n] No" }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = math.max(#message + 4, 30)
  local height = #lines + 2

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " commit.nvim ",
    title_pos = "center",
  })

  local function close_and(cb)
    vim.api.nvim_win_close(win, true)
    if cb then cb() end
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "y", function() close_and(on_yes) end, opts)
  vim.keymap.set("n", "Y", function() close_and(on_yes) end, opts)
  vim.keymap.set("n", "n", function() close_and(on_no) end, opts)
  vim.keymap.set("n", "N", function() close_and(on_no) end, opts)
  vim.keymap.set("n", "<Esc>", function() close_and(on_no) end, opts)
  vim.keymap.set("n", "q", function() close_and(on_no) end, opts)
end

function M.notify_loading()
  vim.notify("commit.nvim: generating commit message...", vim.log.levels.INFO)
end

function M.notify_error(msg)
  vim.notify("commit.nvim: " .. msg, vim.log.levels.ERROR)
end

return M
