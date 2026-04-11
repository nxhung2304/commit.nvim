local M = {}

-- Returns prompt string and a boolean indicating whether the diff was truncated.
function M.build(diff, opts)
  opts = opts or {}
  local max_chars = opts.max_diff_chars or 8000
  local prompt_suffix = opts.prompt_suffix
  local filenames = opts.filenames or {}
  local git_log = opts.git_log or {}

  local truncated = #diff > max_chars
  local diff_text = diff:sub(1, max_chars)

  local parts = {}

  table.insert(parts, [[Write a git commit message from this diff.

Subject: imperative, describe the USER BENEFIT not code structure (max 70 chars)
DO: "enable automatic commit message suggestions" "streamline commit workflow"
DON'T: "add AI generation" "initialize plugin" "create command"

Bullets: 2-3 lines, each starts with "- ", explain benefit + behavior
NO markdown, NO mentions of: tools, APIs, frameworks, code structure

JSON output (one line only):
{"type":"feat","subject":"user benefit verb + noun","bullets":["benefit/behavior","second point"]}]])

  if #filenames > 0 then
    table.insert(parts, "Changed files:\n" .. table.concat(filenames, "\n"))
  end

  if #git_log > 0 then
    table.insert(parts, "Recent commits (match this style):\n" .. table.concat(git_log, "\n"))
  end

  table.insert(parts, "Diff" .. (truncated and " (truncated to " .. max_chars .. " chars)" or "") .. ":\n" .. diff_text)

  if prompt_suffix and prompt_suffix ~= "" then
    table.insert(parts, prompt_suffix)
  end

  return table.concat(parts, "\n\n"), truncated
end

return M
