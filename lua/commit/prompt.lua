local M = {}

function M.build(diff)
  -- Giới hạn diff
  local truncated = diff:sub(1, 1200)

  return string.format([[
Write a git commit message from this diff.

Subject: imperative, describe the USER BENEFIT not code structure (max 70 chars)
DO: "enable automatic commit message suggestions" "streamline commit workflow"
DON'T: "add AI generation" "initialize plugin" "create command"

Bullets: 2-3 lines, each starts with "- ", explain benefit + behavior
NO markdown, NO mentions of: tools, APIs, frameworks, code structure

JSON output (one line only):
{"type":"feat","subject":"user benefit verb + noun","bullets":["benefit/behavior","second point"]}

Diff:
%s]], truncated)
end

return M
