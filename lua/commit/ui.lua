local M = {}

local function format_message(suggestion)
  local lines = {}

  -- Subject line with optional scope
  local scope = suggestion.scope or ""
  local header = (scope ~= "")
    and (suggestion.type .. "(" .. scope .. "): " .. suggestion.subject)
    or  (suggestion.type .. ": " .. suggestion.subject)
  table.insert(lines, header)

  -- Bullets
  if suggestion.bullets and #suggestion.bullets > 0 then
    table.insert(lines, "")
    for _, bullet in ipairs(suggestion.bullets) do
      table.insert(lines, "- " .. bullet)
    end
  end

  return table.concat(lines, "\n")
end

local function format_form_lines(suggestion)
  return {
    "Type:    " .. (suggestion.type or ""),
    "Scope:   " .. (suggestion.scope or ""),
    "Subject: " .. (suggestion.subject or ""),
  }
end

function M.open(suggestion, on_confirm, on_regenerate, opts)
  opts = opts or {}
  local suggestions = (opts.suggestions and #opts.suggestions > 0) and opts.suggestions or { suggestion }
  local current_idx = 1

  -- Form constants
  local LABEL_WIDTH = 9
  local FORM_HEIGHT = 3
  local field_idx = 1

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

  -- Calculate window size
  local ui_config = opts.ui_config or {}
  local bullet_count = suggestions[1].bullets and #suggestions[1].bullets or 0
  local virt_rows = (bullet_count > 0 and (bullet_count + 1) or 0) + 2  -- bullets + separator + hint
  local width = ui_config.width or math.max(70, math.min(80, vim.o.columns - 4))
  local height = math.max(1, math.min(FORM_HEIGHT + virt_rows + #preview_lines, vim.o.lines - 4))

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

  -- Populate form with initial suggestion
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, format_form_lines(suggestions[current_idx]))

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

  -- Bullet virtual lines helper function
  local bullet_ns = vim.api.nvim_create_namespace("commit_bullets")
  local function attach_bullet_virt(s)
    vim.api.nvim_buf_clear_namespace(buf, bullet_ns, 0, -1)
    if s.bullets and #s.bullets > 0 then
      local vlines = { { { "", "Normal" } } }  -- blank separator
      for _, b in ipairs(s.bullets) do
        table.insert(vlines, { { "  - " .. b, "Comment" } })
      end
      -- Anchor to line index 2 (Subject line, 0-indexed)
      vim.api.nvim_buf_set_extmark(buf, bullet_ns, 2, 0, { virt_lines = vlines })
    end
  end

  -- Attach bullets for initial suggestion
  attach_bullet_virt(suggestions[current_idx])

  -- Message validation
  local val_ns = vim.api.nvim_create_namespace("commit_validation")
  local VALID_TYPES = {
    "feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert",
  }

  local function validate()
    vim.api.nvim_buf_clear_namespace(buf, val_ns, 0, -1)
    local type_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    local subj_line = vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] or ""
    local t    = type_line:match("^Type:%s+(.-)%s*$")
    local subj = subj_line:match("^Subject:%s+(.-)%s*$") or ""
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

  -- Label protection: prevent accidental deletion of field prefixes
  local LABELS = { "Type:    ", "Scope:   ", "Subject: " }
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = buf,
    callback = function()
      for i, label in ipairs(LABELS) do
        local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1] or ""
        if not line:find("^" .. label, 1, true) then
          local value = line:gsub("^.-:%s*", "")
          vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { label .. value })
        end
      end
    end,
  })

  -- Build hint text with available bindings
  local function build_hint()
    local hint_parts = { "<CR> confirm", "<Tab> field", "<C-y> copy" }
    if on_regenerate then
      table.insert(hint_parts, "<C-r> regen")
    end
    if #suggestions > 1 then
      table.insert(hint_parts, "[n]/[p] cycle")
    end
    table.insert(hint_parts, "<Esc> cancel")
    return " " .. table.concat(hint_parts, " · ") .. " "
  end

  local hint_ns = vim.api.nvim_create_namespace("commit_hint")
  local function rebuild_hint()
    vim.api.nvim_buf_clear_namespace(buf, hint_ns, 0, -1)
    local hint = build_hint()
    vim.api.nvim_buf_set_extmark(buf, hint_ns, 2, 0, {
      virt_lines = {
        { { string.rep("─", width - 2), "Comment" } },
        { { hint, "Comment" } },
      },
    })
  end

  rebuild_hint()

  -- Focus field helper
  local function focus_field(idx)
    field_idx = idx
    vim.api.nvim_win_set_cursor(win, { idx, LABEL_WIDTH })
    vim.cmd("startinsert!")
  end

  -- Keymaps options (renamed from `opts` to avoid shadowing function parameter)
  local buf_opts = { buffer = buf, noremap = true, silent = true }

  -- Confirm: parse form fields and assemble commit message
  local function confirm()
    local raw = vim.api.nvim_buf_get_lines(buf, 0, 3, false)
    local type_val    = (raw[1] or ""):match("^Type:%s+(.-)%s*$")    or ""
    local scope_val   = (raw[2] or ""):match("^Scope:%s+(.-)%s*$")   or ""
    local subject_val = (raw[3] or ""):match("^Subject:%s+(.-)%s*$") or ""

    if type_val == "" or subject_val == "" then
      vim.notify("commit.nvim: type and subject are required", vim.log.levels.WARN)
      return
    end

    local header = (scope_val ~= "")
      and (type_val .. "(" .. scope_val .. "): " .. subject_val)
      or  (type_val .. ": " .. subject_val)

    local s = suggestions[current_idx]
    local parts = { header }
    if s.bullets and #s.bullets > 0 then
      table.insert(parts, "")
      for _, b in ipairs(s.bullets) do
        table.insert(parts, "- " .. b)
      end
    end

    history.push(s)
    vim.api.nvim_win_close(win, true)
    on_confirm(table.concat(parts, "\n"))
  end

  vim.keymap.set("n", "<CR>", confirm, buf_opts)
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    vim.notify("commit.nvim: cancelled", vim.log.levels.INFO)
  end, buf_opts)

  -- Tab / S-Tab navigation between fields
  vim.keymap.set({ "n", "i" }, "<Tab>", function()
    focus_field((field_idx % FORM_HEIGHT) + 1)
  end, buf_opts)

  vim.keymap.set({ "n", "i" }, "<S-Tab>", function()
    focus_field(((field_idx - 2) % FORM_HEIGHT) + 1)
  end, buf_opts)

  -- Copy to clipboard (assembles same message as confirm)
  vim.keymap.set({ "n", "i" }, "<C-y>", function()
    local raw = vim.api.nvim_buf_get_lines(buf, 0, 3, false)
    local type_val    = (raw[1] or ""):match("^Type:%s+(.-)%s*$")    or ""
    local scope_val   = (raw[2] or ""):match("^Scope:%s+(.-)%s*$")   or ""
    local subject_val = (raw[3] or ""):match("^Subject:%s+(.-)%s*$") or ""
    local header = (scope_val ~= "")
      and (type_val .. "(" .. scope_val .. "): " .. subject_val)
      or  (type_val .. ": " .. subject_val)
    local s = suggestions[current_idx]
    local parts = { header }
    if s.bullets and #s.bullets > 0 then
      table.insert(parts, "")
      for _, b in ipairs(s.bullets) do table.insert(parts, "- " .. b) end
    end
    local msg = table.concat(parts, "\n")
    vim.fn.setreg("+", msg)
    vim.fn.setreg('"', msg)
    vim.notify("commit.nvim: copied to clipboard", vim.log.levels.INFO)
  end, buf_opts)

  -- Update display helper: rewrites form and bullets, restores cursor position
  local function update_display()
    local s = suggestions[current_idx]
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, format_form_lines(s))
    attach_bullet_virt(s)
    rebuild_hint()
    focus_field(field_idx)  -- restore cursor to active field
    local title_str = #suggestions > 1
      and string.format(" commit.nvim %d/%d ", current_idx, #suggestions)
      or " commit.nvim "
    vim.api.nvim_win_set_config(win, { title = title_str })
  end

  -- Cycle through suggestions
  if #suggestions > 1 then
    vim.keymap.set("n", "n", function()
      current_idx = (current_idx % #suggestions) + 1
      update_display()
    end, buf_opts)

    vim.keymap.set("n", "p", function()
      current_idx = ((current_idx - 2) % #suggestions) + 1
      update_display()
    end, buf_opts)
  end

  -- History browsing
  local history = require("commit.history")
  vim.keymap.set("n", "<C-p>", function()
    local prev = history.prev()
    if prev then
      suggestions[current_idx] = prev
      update_display()
    end
  end, buf_opts)

  vim.keymap.set("n", "<C-n>", function()
    local next = history.next()
    if next then
      suggestions[current_idx] = next
      update_display()
    end
  end, buf_opts)

  if on_regenerate then
    local function regenerate()
      vim.api.nvim_win_close(win, true)
      on_regenerate()
    end
    vim.keymap.set("n", "<C-r>", regenerate, buf_opts)
    vim.keymap.set("i", "<C-r>", regenerate, buf_opts)
  end

  -- Start editing on the Type field
  focus_field(1)
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
