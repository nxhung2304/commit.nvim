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
  -- Debug: log raw response for troubleshooting
  vim.notify("Ollama raw response: " .. tostring(raw), vim.log.levels.DEBUG)

  -- Ollama can return either:
  -- 1. Single JSON object (non-streaming)
  -- 2. Multiple JSON objects, one per line (streaming)

  -- First, try to parse as a single JSON object
  local ok, data = pcall(vim.json.decode, raw)
  local text = nil

  if ok and data then
    -- Non-streaming response: single JSON object
    text = data.message and data.message.content
  else
    -- Streaming response: multiple JSON objects, one per line
    -- Parse each line and concatenate the content
    local lines = vim.split(raw, "\n", { trimempty = true })
    local content_parts = {}

    for _, line in ipairs(lines) do
      if line ~= "" then
        local line_ok, line_data = pcall(vim.json.decode, line)
        if line_ok and line_data and line_data.message and line_data.message.content then
          table.insert(content_parts, line_data.message.content)
        end
      end
    end

    if #content_parts > 0 then
      text = table.concat(content_parts, "")
    end
  end

  if not text or text == "" then
    return nil, "Empty response from Ollama (no content found)"
  end

  -- Debug: log extracted text
  vim.notify("Ollama extracted text: " .. tostring(text), vim.log.levels.DEBUG)

  local suggestion = parse_candidate_text(text)
  if not suggestion then
    return nil, "Could not parse commit JSON from response: " .. tostring(text)
  end

  return suggestion, nil
end

-- Exposed for unit testing only
M._parse_response = parse_response
M._parse_candidate_text = parse_candidate_text

function M.suggest(prompt, config, callback)
  -- Ollama runs locally, no API key needed
  local model = config.model or "llama3"
  local base_url = config.base_url or "http://localhost:11434"
  -- Remove trailing slash to avoid double slashes
  base_url = base_url:gsub("/$", "")
  local url = base_url .. "/api/chat"

  local body = vim.json.encode({
    model = model,
    stream = false,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
    options = {
      temperature = config.temperature or 0,
      num_predict = config.max_output_tokens or 1000,
    },
  })

  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(body, "\n"), tmp)

  local stdout_data = {}
  local stderr_data = {}

  vim.fn.jobstart({
    "curl", "-s", "--max-time", "120",
    "-X", "POST",
    "-H", "Content-Type: application/json",
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
      local raw = table.concat(stdout_data, "\n")
      local stderr = table.concat(stderr_data, "\n")

      -- Debug logging
      vim.notify("Ollama curl exit code: " .. tostring(code), vim.log.levels.DEBUG)
      vim.notify("Ollama stdout: " .. tostring(raw), vim.log.levels.DEBUG)
      vim.notify("Ollama stderr: " .. tostring(stderr), vim.log.levels.DEBUG)

      if code ~= 0 then
        -- Check if it's a connection error (Ollama not running)
        if stderr:match("Connection refused") or stderr:match("Couldn't connect") then
          callback(nil, "Ollama not running. Start Ollama first: 'ollama serve'")
        else
          callback(nil, "curl error (exit " .. code .. "): " .. stderr)
        end
        return
      end

      -- Check for empty response
      if raw == "" or raw == nil then
        callback(nil, "Empty response from Ollama. Check if Ollama is running and the model is downloaded. URL: " .. url)
        return
      end

      local result, err = parse_response(raw)
      callback(result, err)
    end,
  })
end

function M.suggest_multi(prompt, config, callback)
  -- Ollama doesn't support multiple candidates in one request,
  -- so we'll make multiple requests
  local model = config.model or "llama3"
  local base_url = config.base_url or "http://localhost:11434"
  -- Remove trailing slash to avoid double slashes
  base_url = base_url:gsub("/$", "")
  local url = base_url .. "/api/chat"
  local num_suggestions = config.candidate_count or 1
  local suggestions = {}
  local completed = 0
  local had_error = false

  local function make_request()
    local body = vim.json.encode({
      model = model,
      stream = false,
      messages = {
        {
          role = "user",
          content = prompt,
        },
      },
      options = {
        temperature = config.temperature or 0,
        num_predict = config.max_output_tokens or 1000,
      },
    })

    local tmp = vim.fn.tempname()
    vim.fn.writefile(vim.split(body, "\n"), tmp)

    local stdout_data = {}
    local stderr_data = {}

    vim.fn.jobstart({
      "curl", "-s", "--max-time", "120",
      "-X", "POST",
      "-H", "Content-Type: application/json",
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
            if msg:match("Connection refused") or msg:match("Couldn't connect") then
              callback(nil, "Ollama not running. Start Ollama first: 'ollama serve'")
            else
              callback(nil, "curl error (exit " .. code .. "): " .. msg)
            end
          end
          return
        end

        if had_error then
          return
        end

        local raw = table.concat(stdout_data, "\n")
        -- Check for empty response
        if raw == "" or raw == nil then
          if not had_error then
            had_error = true
            callback(nil, "Empty response from Ollama")
          end
          return
        end

        -- Parse response (handles both streaming and non-streaming)
        local text = nil
        local ok, data = pcall(vim.json.decode, raw)

        if ok and data and data.message and data.message.content then
          -- Non-streaming response
          text = data.message.content
        else
          -- Streaming response: multiple JSON objects, one per line
          local lines = vim.split(raw, "\n", { trimempty = true })
          local content_parts = {}

          for _, line in ipairs(lines) do
            if line ~= "" then
              local line_ok, line_data = pcall(vim.json.decode, line)
              if line_ok and line_data and line_data.message and line_data.message.content then
                table.insert(content_parts, line_data.message.content)
              end
            end
          end

          if #content_parts > 0 then
            text = table.concat(content_parts, "")
          end
        end

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

  -- Make multiple requests
  for i = 1, num_suggestions do
    make_request(i)
  end
end

return M
