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

function M.open(suggestion, on_confirm)
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
  local width = math.min(math.max(max_width + 4, 60), vim.o.columns - 4)
  local height = math.min(#lines + 4, vim.o.lines - 4)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " commit.nvim ",
    title_pos = "center",
  })

  vim.wo[win].wrap = true

  -- Header hint
  vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("commit_hint"), 0, 0, {
    virt_text = { { " Edit then <CR> to confirm, <Esc> to cancel", "Comment" } },
    virt_text_pos = "eol",
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

  -- Insert mode ở cuối để user chỉnh sửa ngay
  vim.cmd("startinsert!")
end

function M.notify_loading()
  vim.notify("commit.nvim: analyzing diff...", vim.log.levels.INFO)
end

function M.notify_error(msg)
  vim.notify("commit.nvim: " .. msg, vim.log.levels.ERROR)
end

return M
