# Plan: Code Review Fixes

Summary: Fix all bugs, code smells, and improvements identified in the full codebase review.

## Step 1: Critical runtime bugs ✅

- [x] **#1 `build_env` replaces environment** — inherit `vim.uv.os_environ()` instead of empty table
- [x] **#2 Wrong require path in refresh** — `lua.databricks.` → `databricks.`
- [x] **#3 Inverted auth status flag** — swapped true/false semantics
- [x] **#4 Duplicate `---@return` annotation** — removed extra line
- [x] **#5 JSON parser breaks on braces in strings** — made brace counting string-aware

## Step 2: Code smells — correctness ✅

- [x] **#7 Single-run assumption in log module** — store runs by path, added optional `path` param, fixed deploy callback
- [x] **#9 `yq` blocks UI** — replaced `vim.fn.system` with `vim.system().wait()`
- [x] **#11 Manual JSON string building** — use `vim.json.encode` in python/sql/cluster runners
- [x] **#12 Warm cache skips fingerprint** — accept nil fingerprint cache entries

## Step 3: Code smells — hygiene ✅

- [x] **#6 Global `vim.g` state abuse** — moved `databricks_loading` to module-local `bundle_cache.loading`
- [x] **#8 Stale buffer references leak** — added `BufWipeout` autocmd
- [x] **#10 `json_escape` dead code** — removed unused function, documented `parse_json`
- [x] **#17 `vim.tbl_contains` deprecated** — replaced with `vim.list_contains` (src + tests)

## Step 4: Improvements ✅

- [x] **#13 build_env passthrough** — done as #1
- [x] **#14 Replace vim.fn.system with vim.system** — done as #9
- [x] **#15 Configurable on_exit timeout** — added `log.auto_close_ms` config option
- [x] **#16 Telescope soft-optional fallback** — added `vim.ui.select` fallback in resources/variables/log
- [x] **#18 Config helper for deep access** — added `config.get()` helper

## Files impacted

| File | Fixes |
|---|---|
| `lua/databricks/_commands/utils.lua` | #1, #8, #15, #16 (fallback) |
| `lua/databricks/_commands/refresh/run.lua` | #2 |
| `lua/databricks/init.lua` | #3 |
| `lua/databricks/_commands/run/run.lua` | #4 |
| `lua/databricks/_commands/run/util.lua` | #5, #10 |
| `lua/databricks/_commands/run/log.lua` | #7 |
| `lua/databricks/_commands/deploy/run.lua` | #7 (path capture) |
| `lua/databricks/_commands/run/python.lua` | #11 |
| `lua/databricks/_commands/run/sql.lua` | #11 |
| `lua/databricks/_commands/run/cluster.lua` | #11 |
| `lua/databricks/dab.lua` | #9, #17 |
| `lua/databricks/_commands/bundle_cache.lua` | #6, #12 |
| `lua/databricks/_commands/resources/run.lua` | #6, #16 |
| `lua/databricks/_commands/variables/run.lua` | #6, #16 |
| `lua/databricks/_commands/log/run.lua` | #16 |
| `lua/databricks/config.lua` | #15, #18 |
| `tests/bundle_cache_spec.lua` | #17 |
