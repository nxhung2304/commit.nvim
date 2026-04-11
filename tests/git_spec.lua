local git

before_each(function()
  -- Reload module so stubs from previous tests don't leak
  package.loaded["commit.git"] = nil
  git = require("commit.git")
end)

-- ── has_unstaged_changes ────────────────────────────────────────────────────

describe("git.has_unstaged_changes", function()
  it("returns true when porcelain output is non-empty", function()
    local orig = vim.fn.system
    vim.fn.system = function() return " M lua/init.lua\n" end

    assert.is_true(git.has_unstaged_changes())

    vim.fn.system = orig
  end)

  it("returns false when working tree is clean", function()
    local orig = vim.fn.system
    vim.fn.system = function() return "" end

    assert.is_false(git.has_unstaged_changes())

    vim.fn.system = orig
  end)
end)

-- ── get_staged_files ────────────────────────────────────────────────────────

describe("git.get_staged_files", function()
  it("returns list of filenames from staged output", function()
    local orig = vim.fn.system
    vim.fn.system = function()
      vim.cmd("let v:shell_error = 0")
      return "lua/init.lua\nlua/git.lua\n"
    end

    local files = git.get_staged_files()

    assert.equals(2, #files)
    assert.equals("lua/init.lua", files[1])
    assert.equals("lua/git.lua", files[2])

    vim.fn.system = orig
  end)

  it("returns empty list when nothing is staged", function()
    local orig = vim.fn.system
    vim.fn.system = function()
      vim.cmd("let v:shell_error = 0")
      return ""
    end

    local files = git.get_staged_files()

    assert.same({}, files)

    vim.fn.system = orig
  end)

  it("returns empty list on git error", function()
    local orig = vim.fn.system
    vim.fn.system = function()
      vim.cmd("let v:shell_error = 1")
      return "fatal: not a git repo\n"
    end

    local files = git.get_staged_files()

    assert.same({}, files)

    vim.fn.system = orig
  end)
end)

-- ── get_recent_log ──────────────────────────────────────────────────────────

describe("git.get_recent_log", function()
  it("returns parsed commit lines", function()
    local orig = vim.fn.system
    vim.fn.system = function()
      vim.cmd("let v:shell_error = 0")
      return "abc1234 feat: add thing\ndef5678 fix: typo\n"
    end

    local log = git.get_recent_log(2)

    assert.equals(2, #log)
    assert.truthy(log[1]:find("feat: add thing", 1, true))
    assert.truthy(log[2]:find("fix: typo", 1, true))

    vim.fn.system = orig
  end)

  it("returns empty list on error", function()
    local orig = vim.fn.system
    vim.fn.system = function()
      vim.cmd("let v:shell_error = 1")
      return ""
    end

    local log = git.get_recent_log(5)

    assert.same({}, log)

    vim.fn.system = orig
  end)
end)
