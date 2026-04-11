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
  -- Parse Anthropic API response
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or not data then
    return nil, "Could not parse Anthropic response"
  end

  -- Extract text from content array
  local content = data.content and data.content[1]
  local text = content and content.text

  if not text then
    local api_err = data.error and data.error.message
    return nil, api_err or "Empty response from Anthropic"
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
  local api_key = config.api_key or vim.env.ANTHROPIC_API_KEY or os.getenv("ANTHROPIC_API_KEY")
  if not api_key then
    callback(nil, "ANTHROPIC_API_KEY not set")
    return
  end

  local model = config.model or "claude-3-5-sonnet-20241022"
  local url = "https://api.anthropic.com/v1/messages"

  local body = vim.json.encode({
    model = model,
    max_tokens = config.max_output_tokens or 1000,
    temperature = config.temperature or 0,
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
    "-H", "x-api-key: " .. api_key,
    "-H", "anthropic-version: 2023-06-01",
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
  local api_key = config.api_key or vim.env.ANTHROPIC_API_KEY or os.getenv("ANTHROPIC_API_KEY")
  if not api_key then
    callback(nil, "ANTHROPIC_API_KEY not set")
    return
  end

  local model = config.model or "claude-3-5-sonnet-20241022"
  local url = "https://api.anthropic.com/v1/messages"

  -- Anthropic doesn't support multiple candidates in one request,
  -- so we'll make multiple requests
  local num_suggestions = config.candidate_count or 1
  local suggestions = {}
  local completed = 0
  local had_error = false

  local function make_request()
    local body = vim.json.encode({
      model = model,
      max_tokens = config.max_output_tokens or 1000,
      temperature = config.temperature or 0,
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
      "-H", "x-api-key: " .. api_key,
      "-H", "anthropic-version: 2023-06-01",
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
        completed = completed + 1

        if code ~= 0 then
          if not had_error then
            had_error = true
            local msg = table.concat(stderr_data, "\n")
            callback(nil, "curl error (exit " .. code .. "): " .. msg)
          end
          return
        end

        if had_error then
          return
        end

        local raw = table.concat(stdout_data, "\n")
        local ok, data = pcall(vim.json.decode, raw)
        if not ok or not data then
          if not had_error then
            had_error = true
            callback(nil, "Could not parse Anthropic response")
          end
          return
        end

        local content = data.content and data.content[1]
        local text = content and content.text
        if text then
          local suggestion = parse_candidate_text(text)
          if suggestion then
            table.insert(suggestions, suggestion)
          end
        end

        -- All requests completed
        if completed == num_suggestions then
          if #suggestions == 0 then
            callback(nil, "Could not parse any suggestions from response")
          else
            callback(suggestions, nil)
          end
        end
      end,
    })
  end

  -- Make multiple requests sequentially
  for i = 1, num_suggestions do
    make_request(i)
  end
end

return M
