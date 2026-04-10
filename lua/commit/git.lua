local M = {}

function M.get_staged_diff()
  local result = vim.fn.system("git diff --staged")
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to get git diff"
  end
  return result ~= "" and result or nil, nil
end

function M.has_unstaged_changes()
  local result = vim.fn.system("git status --porcelain")
  return result ~= ""
end

function M.stage_all()
  vim.fn.system("git add -A")
  return vim.v.shell_error == 0
end

function M.do_commit(message)
  local escaped = message:gsub('"', '\\"')
  local result = vim.fn.system(string.format('git commit -m "%s"', escaped))
  if vim.v.shell_error ~= 0 then
    return false, result
  end
  return true, result
end

return M
