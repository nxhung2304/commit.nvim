local M = {}

-- Circular buffer for storing suggestions, max 10 entries
local MAX_ENTRIES = 10
local buffer = {}
local head = 0  -- index of next write slot
local count = 0  -- number of valid entries
local cursor = 0  -- browsing cursor (0 = most recent, increases backwards in time)

--- Add a suggestion to history (resets cursor to most recent)
function M.push(suggestion)
  buffer[head] = suggestion
  head = (head % MAX_ENTRIES) + 1
  if count < MAX_ENTRIES then
    count = count + 1
  end
  cursor = 0
end

--- Get the previous (older) suggestion
function M.prev()
  if count == 0 then return nil end
  if cursor < count - 1 then
    cursor = cursor + 1
  end
  local idx = (head - 1 - cursor) % MAX_ENTRIES
  return buffer[idx]
end

--- Get the next (newer) suggestion
function M.next()
  if count == 0 then return nil end
  if cursor > 0 then
    cursor = cursor - 1
  end
  local idx = (head - 1 - cursor) % MAX_ENTRIES
  return buffer[idx]
end

--- Get the current suggestion being browsed (most recent if cursor is 0)
function M.current()
  if count == 0 then return nil end
  local idx = (head - 1 - cursor) % MAX_ENTRIES
  return buffer[idx]
end

--- Reset cursor to most recent entry (used on new generation)
function M.reset_cursor()
  cursor = 0
end

return M
