-- .luacheckrc
-- vim is injected by the Neovim runtime
read_globals = { "vim" }

-- Allow busted/plenary test globals in spec files
files["tests/**/*_spec.lua"] = {
  globals = { "describe", "it", "before_each", "after_each", "pending", "assert" },
}
files["tests/minimal_init.lua"] = {
  globals = { "vim" },
}
