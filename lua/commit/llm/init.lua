local M = {}

local providers = {
  gemini = require("commit.llm.gemini"),
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

return M
