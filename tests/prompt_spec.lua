local prompt = require("commit.prompt")

describe("prompt.build", function()
  it("returns false for truncated when diff is within limit", function()
    local diff = "diff --git a/foo.lua b/foo.lua\n+local x = 1"
    local result, truncated = prompt.build(diff, { max_diff_chars = 1000 })

    assert.is_false(truncated)
    assert.truthy(result:find("Diff", 1, true))
    assert.truthy(result:find(diff, 1, true))
  end)

  it("truncates diff and returns true when exceeding max_diff_chars", function()
    local diff = string.rep("a", 200)
    local result, truncated = prompt.build(diff, { max_diff_chars = 100 })

    assert.is_true(truncated)
    assert.truthy(result:find("truncated", 1, true))
  end)

  it("truncated diff is exactly max_diff_chars long in prompt", function()
    local diff = string.rep("x", 500)
    local result, truncated = prompt.build(diff, { max_diff_chars = 50 })

    assert.is_true(truncated)
    -- The diff portion should be cut to 50 x's
    assert.truthy(result:find(string.rep("x", 50), 1, true))
    assert.falsy(result:find(string.rep("x", 51), 1, true))
  end)

  it("includes filenames section when provided", function()
    local result, _ = prompt.build("diff", {
      filenames = { "lua/init.lua", "lua/git.lua" },
    })

    assert.truthy(result:find("Changed files", 1, true))
    assert.truthy(result:find("lua/init.lua", 1, true))
    assert.truthy(result:find("lua/git.lua", 1, true))
  end)

  it("omits filenames section when list is empty", function()
    local result, _ = prompt.build("diff", { filenames = {} })

    assert.falsy(result:find("Changed files", 1, true))
  end)

  it("includes git log section when provided", function()
    local result, _ = prompt.build("diff", {
      git_log = { "abc1234 feat: initial commit", "def5678 fix: typo" },
    })

    assert.truthy(result:find("Recent commits", 1, true))
    assert.truthy(result:find("abc1234", 1, true))
    assert.truthy(result:find("def5678", 1, true))
  end)

  it("omits git log section when list is empty", function()
    local result, _ = prompt.build("diff", { git_log = {} })

    assert.falsy(result:find("Recent commits", 1, true))
  end)

  it("appends prompt_suffix when provided", function()
    local result, _ = prompt.build("diff", {
      prompt_suffix = "Always respond in Japanese.",
    })

    assert.truthy(result:find("Always respond in Japanese.", 1, true))
  end)

  it("omits suffix when prompt_suffix is empty string", function()
    local result, _ = prompt.build("diff", { prompt_suffix = "" })

    assert.truthy(type(result) == "string")
    assert.falsy(result:find("Always", 1, true))
  end)

  it("uses default max_diff_chars of 8000 when not specified", function()
    local diff = string.rep("y", 100)
    local _, truncated = prompt.build(diff, {})

    assert.is_false(truncated)
  end)

  it("always includes the instruction block", function()
    local result, _ = prompt.build("diff", {})

    assert.truthy(result:find("Write a git commit message", 1, true))
    assert.truthy(result:find('"type"', 1, true))
    assert.truthy(result:find('"subject"', 1, true))
    assert.truthy(result:find('"bullets"', 1, true))
  end)
end)
