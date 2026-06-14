TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

PANVIMDOC_DIR=deps/panvimdoc

.PHONY: test doc

test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

$(PANVIMDOC_DIR):
	git clone --depth 1 https://github.com/kdheepak/panvimdoc.git $@

doc: $(PANVIMDOC_DIR)
	$(PANVIMDOC_DIR)/panvimdoc.sh \
		--project-name databricks \
		--input-file doc/vimdoc.md \
		--vim-version 'NVIM v0.12.3' \
		--toc true \
		--description 'Databricks CLI integration for Neovim' \
		--dedup-subheadings true \
		--treesitter true \
		--ignore-rawblocks true
	nvim --headless -c 'helptags doc' -c 'qa'
