# commit.nvim — Roadmap

Based on feedback from ChatGPT, Gemini, and internal codebase audit.

---

## Current State: v0.1.0 (Prototype)

| Aspect | Score |
|---|---|
| Architecture | 8/10 |
| Error Handling | 3/10 |
| Security | 2/10 |
| Testing | 0/10 |
| Documentation | 5/10 |
| **Overall** | **35/100 — not production-ready** |

---

## v0.2.0 — Security & Stability (Blocker Release)

> Must ship before any feature work.

### Critical Bug Fixes

- [ ] **Shell injection** (`git.lua:22`) — replace string interpolation with `vim.fn.shellescape()` or pass args as array to `jobstart`
- [ ] **API key exposure** (`gemini.lua:57`) — move API key from URL query param to `Authorization` header
- [ ] **Temp file leak** (`gemini.lua:74`) — ensure cleanup runs in `on_exit` even on error paths
- [ ] **No curl timeout** (`gemini.lua:77`) — add `--max-time 30` flag to curl command
- [ ] **Config params ignored** (`gemini.lua:68`) — pass `config.temperature` and `config.max_output_tokens` to Gemini request body
- [ ] **No config validation** (`init.lua:10`) — validate required fields in `setup()`, fail fast with clear error message

### Minor Fixes

- [ ] Validate `.git` directory exists before any git operations
- [ ] Handle empty/whitespace-only diffs gracefully
- [ ] Fix window layout on small terminals (negative dimension guard in `ui.lua:34`)

---

## v0.3.0 — Core UX Improvements

### Prompt & Context

- [x] Configurable diff size limit (default: 1200 chars) via `setup({ max_diff_chars = N })`
- [x] `exclude_patterns` config to skip lock files, minified files (e.g. `package-lock.json`, `*.min.js`)
- [x] Include filenames and function names in prompt for better AI context
- [x] Include recent `git log` (last 5 commits) in prompt to match repo style
- [x] Warn user when diff is truncated

### UI

- [x] `<C-r>` keybind inside float window to regenerate suggestion
- [x] Show loading indicator while waiting for LLM response
- [x] `setup({ prompt_suffix = "..." })` for custom instructions (language, ticket refs, etc.)

### Documentation

- [x] Add `doc/commit.txt` (Vimdoc) — `:help commit.nvim`
- [ ] Add demo GIF to README
- [x] Add troubleshooting section to README

---

## v0.4.0 — Testing & CI

- [x] Add `tests/` directory using `plenary.nvim`
- [x] Unit tests for: `git.lua`, `prompt.lua`, `llm/gemini.lua` (JSON parsing, fallback)
- [x] GitHub Actions workflow — run tests on push/PR
- [x] Lua linting via `luacheck` in CI

---

## v0.5.0 — Workflow Integration

> ChatGPT feedback: "devs use `git commit`, not `:Commit`" — this is the adoption key.

### Fugitive (`vim-fugitive`)

- [x] Auto-detect fugitive commit buffer open (`BufEnter` on `.git/COMMIT_EDITMSG`)
- [x] Pre-fill buffer with AI-generated message
- [x] Keybind (e.g. `<leader>ai`) inside commit buffer to trigger generation on demand
- [x] Opt-in via config: `setup({ fugitive = { enabled = true, auto_fill = false } })`

### Neogit

- [x] Hook into Neogit commit popup via its API / `autocmd`
- [x] Pre-fill commit message field with AI suggestion
- [x] User edits inline, confirms with Neogit's native flow
- [x] Opt-in via config: `setup({ neogit = { enabled = true } })`

### Standalone

- [x] `:CommitSmart` — opens commit buffer, auto-fills, user confirms (fallback for users without Fugitive/Neogit)

> Both integrations must be **opt-in** and **auto-detected** — no hard dependency on either plugin.

---

## v0.6.0 — Interactive UI

> ChatGPT feedback: "IDE experience very missing in Neovim"

- [ ] Structured form inside float window:
  ```
  Type:    [feat      ]
  Scope:   [auth      ]
  Message: add login with Google
  ```
- [ ] Tab between fields
- [ ] Inline editing with confirmation via `<CR>`
- [ ] Escape cancels without committing

---

## v1.0.0 — Multi-Provider Support

> Architecture already supports this via `lua/commit/llm/` abstraction.
- [x] **OpenAI** (`lua/commit/llm/openai.lua`) — GPT-4o
- [x] **Anthropic** (`lua/commit/llm/claude.lua`) — Claude
- [x] **Ollama** (`lua/commit/llm/ollama.lua`) — local models (llama3, qwen, etc.)
  - High priority: enterprise users with air-gap / no-cloud policies
- [x] Provider selection via `setup({ provider = "openai|anthropic|gemini", model = "..." })`

---

## v1.1.0 — Git Intelligence Layer

> "Git intelligence layer" — ChatGPT's top recommendation.

- [ ] Auto-detect `type` from diff patterns (new file → `feat`, bug fix patterns → `fix`)
- [ ] Auto-detect `scope` from changed file paths (`auth/`, `ui/`, `api/`)
- [ ] Detect breaking changes from diff
- [ ] Self-adaptive: scan `git log` to learn project's commit style

---

## v2.0.0 — Team Mode

- [ ] Shared config file (`.commit-nvim.json` at repo root)
- [ ] Enforce commit style across team
- [ ] Shared `scope` allowlist
- [ ] Shared custom prompt prefix per repo

---

## Release Priority Summary

| Version | Theme | Status |
|---|---|---|
| v0.1.0 | Working prototype | Done |
| v0.2.0 | Security & stability | **Done** |
| v0.3.0 | Core UX improvements | **Done** |
| v0.4.0 | Testing & CI | **Done** |
| v0.5.0 | Fugitive + Neogit integration | **Done** |
| v0.6.0 | Interactive UI | Done |
| v1.0.0 | Multi-provider | **Done** |
| v1.1.0 | Git intelligence | Planned |
| v2.0.0 | Team mode | Future |
