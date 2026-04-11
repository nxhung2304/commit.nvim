local M = {}

local function parse_candidate_text(text)
  -- Parse a single candidate text (expected to be JSON)
  local ok, suggestion = pcall(vim.json.decode, text)
  if not ok or not suggestion then
    -- Fallback: try extract fields from incomplete JSON
    local t = text:match('"type"%s*:%s*"([^"]*)"')
    local subj = text:match('"subject"%s*:%s*"([^"]*)"')

    if not t or not subj then
      return nil
    end

    -- Use fallback suggestion without bullets or scope
    suggestion = { type = t, subject = subj, scope = "", bullets = {} }
  end

  if not suggestion.type or not suggestion.subject then
    return nil
  end

  return {
    type = suggestion.type,
    subject = suggestion.subject,
    scope = suggestion.scope or "",
    bullets = suggestion.bullets or {},
  }
end

local function parse_response(raw)
  -- Parse OpenAI API response
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or not data then
    return nil, "Could not parse OpenAI response"
  end

  -- Extract text from choices[1].message.content
  local choice = data.choices and data.choices[1]
  local text = choice and choice.message and choice.message.content

  if not text then
    local api_err = data.error and data.error.message
    return nil, api_err or "Empty response from OpenAI"
  end

  local suggestion = parse_candidate_text(text)
  if not suggestion then
    return nil, "Could not parse commit JSON from response"
  end

  return suggestion, nil
end

-- Exposed for unit testing only
M._parse_response = parse_response
M._parse_candidate_text = parse_candidate_text

function M.suggest(prompt, config, callback)
  local api_key = config.api_key or vim.env.OPENAI_API_KEY or os.getenv("OPENAI_API_KEY")
  if not api_key then
    callback(nil, "OPENAI_API_KEY not set")
    return
  end

  local model = config.model or "gpt-4o-mini"
  local url = "https://api.openai.com/v1/chat/completions"

  local body = vim.json.encode({
    model = model,
    temperature = config.temperature or 0,
    max_tokens = config.max_output_tokens or 1000,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
  })

  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(body, "\n"), tmp)

  local stdout_data = {}
  local stderr_data = {}

  vim.fn.jobstart({
    "curl", "-s", "--max-time", "30",
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. api_key,
    "-d", "@" .. tmp,
    url,
  }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout_data = data
    end,
    on_stderr = function(_, data)
      stderr_data = data
    end,
    on_exit = function(_, code)
      vim.fn.delete(tmp)
      if code ~= 0 then
        local msg = table.concat(stderr_data, "\n")
        callback(nil, "curl error (exit " .. code .. "): " .. msg)
        return
      end
      local raw = table.concat(stdout_data, "\n")
      local result, err = parse_response(raw)
      callback(result, err)
    end,
  })
end

function M.suggest_multi(prompt, config, callback)
  local api_key = config.api_key or vim.env.OPENAI_API_KEY or os.getenv("OPENAI_API_KEY")
  if not api_key then
    callback(nil, "OPENAI_API_KEY not set")
    return
  end

  local model = config.model or "gpt-4o-mini"
  local url = "https://api.openai.com/v1/chat/completions"
  local num_suggestions = config.candidate_count or 1

  -- OpenAI's n parameter can request multiple completions in one request
  local body = vim.json.encode({
    model = model,
    temperature = config.temperature or 0,
    max_tokens = config.max_output_tokens or 1000,
    n = num_suggestions,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
  })

  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(body, "\n"), tmp)

  local stdout_data = {}
  local stderr_data = {}

  vim.fn.jobstart({
    "curl", "-s", "--max-time", "30",
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. api_key,
    "-d", "@" .. tmp,
    url,
  }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout_data = data
    end,
    on_stderr = function(_, data)
      stderr_data = data
    end,
    on_exit = function(_, code)
      vim.fn.delete(tmp)
      if code ~= 0 then
        local msg = table.concat(stderr_data, "\n")
        callback(nil, "curl error (exit " .. code .. "): " .. msg)
        return
      end
      local raw = table.concat(stdout_data, "\n")

      -- Parse OpenAI API response with multiple choices
      local ok, data = pcall(vim.json.decode, raw)
      if not ok or not data then
        callback(nil, "Could not parse OpenAI response")
        return
      end

      if not data.choices or #data.choices == 0 then
        local api_err = data.error and data.error.message
        callback(nil, api_err or "Empty response from OpenAI")
        return
      end

      -- Parse all choices
      local suggestions = {}
      for _, choice in ipairs(data.choices) do
        local text = choice and choice.message and choice.message.content
        if text then
          local suggestion = parse_candidate_text(text)
          if suggestion then
            table.insert(suggestions, suggestion)
          end
        end
      end

      if #suggestions == 0 then
        callback(nil, "Could not parse any suggestions from response")
        return
      end

      callback(suggestions, nil)
    end,
  })
end

return M
