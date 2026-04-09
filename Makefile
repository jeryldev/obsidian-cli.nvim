.PHONY: test test-watch lint format check

# Run the full test suite via plenary.
# Requires plenary.nvim to be installed at the default Lazy location.
test:
	@nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests {minimal_init = 'tests/minimal_init.lua'}"

# Run a single test file: `make test-file FILE=tests/util_spec.lua`
test-file:
	@nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

# Check formatting (CI) without modifying files.
lint:
	@stylua --check lua/ tests/
	@selene --display-style=quiet lua/ tests/

# Apply formatting in place.
format:
	@stylua lua/ tests/

# Run both tests and lint. Use this before committing.
check: lint test
