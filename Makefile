PLENARY_DIR ?= $(HOME)/.local/share/nvim/site/pack/vendor/start/plenary.nvim

.PHONY: test lint

test:
	PLENARY_DIR=$(PLENARY_DIR) nvim --headless \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua'}"

lint:
	luacheck lua/ plugin/ tests/
