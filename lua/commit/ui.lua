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

function M.open(suggestion, on_confirm, on_regenerate, opts)
  opts = opts or {}
  local suggestions = (opts.suggestions and #opts.suggestions > 0) and opts.suggestions or { suggestion }
  local current_idx = 1

  local function update_display()
    local current_suggestion = suggestions[current_idx]
    local message = format_message(current_suggestion)
    local lines = vim.split(message, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Update title with suggestion counter
    local title_str = " commit.nvim "
    if #suggestions > 1 then
      title_str = string.format(" commit.nvim %d/%d ", current_idx, #suggestions)
    end
    vim.api.nvim_win_set_config(win, { title = title_str })
  end

  -- Diff preview: staged files
  local git = require("commit.git")
  local staged_files = git.get_staged_files()
  local preview_lines = {}
  if #staged_files > 0 then
    table.insert(preview_lines, "Staged files:")
    for _, f in ipairs(staged_files) do
      table.insert(preview_lines, "  " .. f)
    end
    table.insert(preview_lines, "")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "gitcommit"
  vim.bo[buf].bufhidden = "wipe"

  -- Calculate size based on content
  local max_width = 0
  local message = format_message(suggestion)
  local lines = vim.split(message, "\n")
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, #line)
  end
  local ui_config = opts.ui_config or {}
  local width = ui_config.width or math.max(1, math.min(math.max(max_width + 4, 60), vim.o.columns - 4))
  -- +2 for the separator and hint lines rendered via virt_lines at the bottom
  local height = math.max(1, math.min(#lines + 2 + #preview_lines, vim.o.lines - 4))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = ui_config.border or "rounded",
    title = #suggestions > 1 and string.format(" commit.nvim %d/%d ", current_idx, #suggestions) or " commit.nvim ",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.wo[win].wrap = true

  -- Diff preview via virtual lines above
  if #preview_lines > 0 then
    local preview_ns = vim.api.nvim_create_namespace("commit_diff_preview")
    local virt_lines = {}
    for _, pline in ipairs(preview_lines) do
      table.insert(virt_lines, { { pline, "Comment" } })
    end
    vim.api.nvim_buf_set_extmark(buf, preview_ns, 0, 0, {
      virt_lines = virt_lines,
      virt_lines_above = true,
    })
  end

  -- Message validation
  local val_ns = vim.api.nvim_create_namespace("commit_validation")
  local VALID_TYPES = {
    "feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert",
  }

  local function validate()
    vim.api.nvim_buf_clear_namespace(buf, val_ns, 0, -1)
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    local t, subj = line:match("^(%a+):%s*(.*)$")
    if t then
      local valid_type = vim.tbl_contains(VALID_TYPES, t)
      local warnings = {}
      if not valid_type then
        table.insert(warnings, "unknown type")
      end
      if #subj > 72 then
        table.insert(warnings, "subject >" .. #subj .. " chars")
      end
      if #warnings == 0 then
        vim.api.nvim_buf_set_extmark(buf, val_ns, 0, 0, {
          virt_text = { { "  ✓", "DiagnosticOk" } },
          virt_text_pos = "eol",
        })
      else
        vim.api.nvim_buf_set_extmark(buf, val_ns, 0, 0, {
          virt_text = { { "  ⚠ " .. table.concat(warnings, ", "), "DiagnosticWarn" } },
          virt_text_pos = "eol",
        })
      end
    end
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = validate,
  })
  validate()

  -- Build hint text with available bindings
  local hint_parts = { "<CR> confirm", "<C-y> copy" }
  if on_regenerate then
    table.insert(hint_parts, "<C-r> regen")
  end
  if #suggestions > 1 then
    table.insert(hint_parts, "[n]/[p] cycle")
  end
  table.insert(hint_parts, "<Esc> cancel")
  local hint = " " .. table.concat(hint_parts, " · ") .. " "
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
    -- Push to history before confirming
    history.push(suggestions[current_idx])
    vim.api.nvim_win_close(win, true)
    on_confirm(final_msg)
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", confirm, opts)
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    vim.notify("commit.nvim: cancelled", vim.log.levels.INFO)
  end, opts)

  -- Copy to clipboard
  vim.keymap.set({ "n", "i" }, "<C-y>", function()
    local final_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local msg = table.concat(final_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    vim.fn.setreg("+", msg)
    vim.fn.setreg('"', msg)
    vim.notify("commit.nvim: copied to clipboard", vim.log.levels.INFO)
  end, opts)

  -- Cycle through suggestions
  if #suggestions > 1 then
    vim.keymap.set("n", "n", function()
      current_idx = (current_idx % #suggestions) + 1
      update_display()
    end, opts)

    vim.keymap.set("n", "p", function()
      current_idx = ((current_idx - 2) % #suggestions) + 1
      update_display()
    end, opts)
  end

  -- History browsing
  local history = require("commit.history")
  vim.keymap.set("n", "<C-p>", function()
    local prev = history.prev()
    if prev then
      suggestions[current_idx] = prev
      update_display()
    end
  end, opts)

  vim.keymap.set("n", "<C-n>", function()
    local next = history.next()
    if next then
      suggestions[current_idx] = next
      update_display()
    end
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

function M.error_modal(msg, on_retry)
  local lines = { "Error: " .. msg, "", "  [r] Retry    [q] Dismiss" }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = math.max(#msg + 10, 30)
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
    if cb then
      cb()
    end
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "r", function()
    close_and(on_retry)
  end, opts)
  vim.keymap.set("n", "q", function()
    close_and(nil)
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    close_and(nil)
  end, opts)
end

function M.notify_loading()
  vim.notify("commit.nvim: generating commit message...", vim.log.levels.INFO)
end

function M.notify_error(msg)
  vim.notify("commit.nvim: " .. msg, vim.log.levels.ERROR)
end

return M
