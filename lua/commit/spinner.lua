local M = {}

-- Animated spinner using vim.loop.new_timer()
-- Frames: braille spinner
local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- Create a spinner that updates a buffer extmark
-- @param buf buffer handle
-- @param line line number (0-indexed)
-- @param ns_name namespace name for the extmark
-- @return handle with :start() and :stop(final_text) methods
function M.new(buf, line, ns_name)
  local ns = vim.api.nvim_create_namespace(ns_name)
  local timer = vim.loop.new_timer()
  local frame = 0
  local mark_id = nil

  local function tick()
    if not vim.api.nvim_buf_is_valid(buf) then
      timer:stop()
      timer:close()
      return
    end
    frame = (frame % #FRAMES) + 1
    if mark_id then
      vim.api.nvim_buf_del_extmark(buf, ns, mark_id)
    end
    mark_id = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
      virt_text = { { FRAMES[frame], "Comment" } },
    })
  end

  return {
    start = function()
      timer:start(0, 80, vim.schedule_wrap(tick))
    end,
    stop = function(final_text)
      timer:stop()
      timer:close()
      if mark_id and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_del_extmark(buf, ns, mark_id)
      end
      if final_text then
        mark_id = vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
          virt_text = { { final_text, "Comment" } },
        })
      end
    end,
  }
end

--- Create a notification-based spinner for use without a target buffer
-- @param label text to show next to spinner
-- @return handle with :start() and :stop(final_text) methods
function M.start_notify(label)
  local timer = vim.loop.new_timer()
  local frame = 0
  local notif_id = nil
  local stopped = false

  local function tick()
    if stopped then return end
    frame = (frame % #FRAMES) + 1
    local msg = FRAMES[frame] .. " " .. label
    notif_id = vim.notify(msg, vim.log.levels.INFO, { replace = notif_id })
  end

  return {
    start = function()
      tick()  -- show first frame immediately
      timer:start(80, 80, vim.schedule_wrap(tick))
    end,
    stop = function(final_text)
      stopped = true
      timer:stop()
      timer:close()
      if final_text then
        vim.notify(final_text, vim.log.levels.INFO)
      end
    end,
  }
end

return M
