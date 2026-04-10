local M = {}

local function parse_response(raw)
  -- Parse Gemini API response
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or not data then
    return nil, "Could not parse Gemini response"
  end

  -- Lấy text từ candidates[1].content.parts[1].text
  local candidate = data.candidates and data.candidates[1]
  local text = candidate
    and candidate.content
    and candidate.content.parts
    and candidate.content.parts[1]
    and candidate.content.parts[1].text

  if not text then
    local api_err = data.error and data.error.message
    return nil, api_err or "Empty response from Gemini"
  end

  -- LLM trả về JSON, parse tiếp
  local ok2, suggestion = pcall(vim.json.decode, text)
  if not ok2 or not suggestion then
    -- Fallback: try extract fields from incomplete JSON
    local t = text:match('"type"%s*:%s*"([^"]*)"')
    local subj = text:match('"subject"%s*:%s*"([^"]*)"')

    if not t or not subj then
      return nil, "Could not parse commit JSON from response"
    end

    -- Use fallback suggestion without bullets
    suggestion = { type = t, subject = subj, bullets = {} }
  end

  if not suggestion.type or not suggestion.subject then
    return nil, "Missing type or subject in response"
  end

  return {
    type = suggestion.type,
    subject = suggestion.subject,
    bullets = suggestion.bullets or {},
  }, nil
end

function M.suggest(prompt, config, callback)
  local api_key = config.api_key or vim.env.GEMINI_API_KEY or os.getenv("GEMINI_API_KEY")
  if not api_key then
    callback(nil, "GEMINI_API_KEY not set")
    return
  end

  local model = config.model or "gemini-2.0-flash"
  local url = string.format(
    "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
    model,
    api_key
  )

  local body = vim.json.encode({
    contents = {
      { parts = { { text = prompt } } },
    },
    generationConfig = {
      temperature = 0,
      maxOutputTokens = 1000,
    },
  })

  -- Ghi body ra file tạm để truyền vào curl
  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(body, "\n"), tmp)

  vim.fn.jobstart({
    "curl", "-s", "-X", "POST",
    "-H", "Content-Type: application/json",
    "-d", "@" .. tmp,
    url,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      vim.fn.delete(tmp)
      local raw = table.concat(data, "\n")
      local result, err = parse_response(raw)
      callback(result, err)
    end,
    on_stderr = function(_, data)
      local msg = table.concat(data, "\n")
      if msg ~= "" then
        vim.fn.delete(tmp)
        callback(nil, "curl error: " .. msg)
      end
    end,
  })
end

return M
