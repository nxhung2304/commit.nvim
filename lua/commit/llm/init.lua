local M = {}

local providers = {
  gemini = require("commit.llm.gemini"),
  anthropic = require("commit.llm.claude"),
  openai = require("commit.llm.openai"),
  ollama = require("commit.llm.ollama"),
}

function M.suggest(prompt, config, callback)
  local provider = config.provider or "gemini"
  local impl = providers[provider]

  if not impl then
    callback(nil, "Unknown provider: " .. provider)
    return
  end

  impl.suggest(prompt, config, callback)
end

function M.suggest_multi(prompt, config, callback)
  local provider = config.provider or "gemini"
  local impl = providers[provider]

  if not impl then
    callback(nil, "Unknown provider: " .. provider)
    return
  end

  if not impl.suggest_multi then
    callback(nil, "Provider does not support multiple suggestions")
    return
  end

  impl.suggest_multi(prompt, config, callback)
end

return M
