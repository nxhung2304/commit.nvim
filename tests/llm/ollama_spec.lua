local ollama = require("commit.llm.ollama")
local parse = ollama._parse_response

-- Helper: wrap LLM text output inside a full Ollama API response envelope.
local function make_raw(text)
  return vim.json.encode({
    model = "llama3",
    created_at = "2024-01-01T00:00:00Z",
    message = {
      role = "assistant",
      content = text,
    },
    done = true,
  })
end

describe("ollama._parse_response", function()
  it("parses a valid response with all fields", function()
    local raw = make_raw(vim.json.encode({
      type = "feat",
      subject = "add login with Google",
      bullets = { "enables OAuth flow", "stores token securely" },
    }))

    local result, err = parse(raw)

    assert.is_nil(err)
    assert.equals("feat", result.type)
    assert.equals("add login with Google", result.subject)
    assert.equals(2, #result.bullets)
    assert.equals("enables OAuth flow", result.bullets[1])
  end)

  it("returns empty bullets table when bullets field is absent", function()
    local raw = make_raw(vim.json.encode({
      type = "fix",
      subject = "correct off-by-one error",
    }))

    local result, err = parse(raw)

    assert.is_nil(err)
    assert.equals("fix", result.type)
    assert.same({}, result.bullets)
  end)

  it("falls back to regex when LLM returns incomplete JSON", function()
    -- Simulate truncated/malformed JSON from LLM
    local partial = '{"type":"chore","subject":"update dependencies'
    local raw = make_raw(partial)

    local result, err = parse(raw)

    assert.is_nil(err)
    assert.equals("chore", result.type)
    assert.equals("update dependencies", result.subject)
    assert.same({}, result.bullets)
  end)

  it("returns error when outer Ollama response JSON is malformed", function()
    local result, err = parse("this is not json")

    assert.is_nil(result)
    assert.truthy(err)
  end)

  it("returns API error message when message is absent", function()
    local raw = vim.json.encode({
      model = "llama3",
      error = "model not found",
    })

    local result, err = parse(raw)

    assert.is_nil(result)
    assert.equals("model not found", err)
  end)

  it("returns generic error when message is absent and no error field", function()
    local raw = vim.json.encode({ model = "llama3", done = true })

    local result, err = parse(raw)

    assert.is_nil(result)
    assert.truthy(err)
  end)

  it("returns error when LLM text is unstructured and regex also fails", function()
    local raw = make_raw("Sorry, I cannot help with that.")

    local result, err = parse(raw)

    assert.is_nil(result)
    assert.truthy(err)
  end)

  it("returns error when parsed JSON is missing both type and subject", function()
    local raw = make_raw(vim.json.encode({ bullets = { "something" } }))

    local result, err = parse(raw)

    assert.is_nil(result)
    assert.truthy(err)
  end)

  it("returns error when parsed JSON has subject but no type", function()
    local raw = make_raw(vim.json.encode({ subject = "do something" }))

    local result, err = parse(raw)

    assert.is_nil(result)
    assert.truthy(err)
  end)
end)
