local M = {}

local function in_git_repo()
  vim.fn.system({ "git", "rev-parse", "--git-dir" })
  return vim.v.shell_error == 0
end

function M.get_staged_diff(exclude_patterns)
  if not in_git_repo() then
    return nil, "Not inside a git repository"
  end
  local cmd = { "git", "diff", "--staged" }
  if exclude_patterns and #exclude_patterns > 0 then
    for _, pattern in ipairs(exclude_patterns) do
      table.insert(cmd, ":(exclude)" .. pattern)
    end
  end
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to get git diff"
  end
  if result == nil or result:match("^%s*$") then
    return nil, nil
  end
  return result, nil
end

function M.get_staged_files()
  local result = vim.fn.system({ "git", "diff", "--staged", "--name-only" })
  if vim.v.shell_error ~= 0 or not result or result:match("^%s*$") then
    return {}
  end
  local files = {}
  for line in result:gmatch("[^\n]+") do
    table.insert(files, line)
  end
  return files
end

function M.get_recent_log(n)
  n = n or 5
  local result = vim.fn.system({ "git", "log", "--oneline", "-" .. n })
  if vim.v.shell_error ~= 0 or not result or result:match("^%s*$") then
    return {}
  end
  local commits = {}
  for line in result:gmatch("[^\n]+") do
    table.insert(commits, line)
  end
  return commits
end

function M.has_unstaged_changes()
  local result = vim.fn.system({ "git", "status", "--porcelain" })
  return result ~= ""
end

function M.stage_all()
  vim.fn.system({ "git", "add", "-A" })
  return vim.v.shell_error == 0
end

function M.do_commit(message)
  local result = vim.fn.system({ "git", "commit", "-m", message })
  if vim.v.shell_error ~= 0 then
    return false, result
  end
  return true, result
end

return M
