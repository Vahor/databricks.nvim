# databricks.nvim — Complete Specification

> Neovim extension for Databricks. Backend is the [Databricks CLI](https://github.com/databricks/cli).
> Inspired by the [Databricks VSCode extension](https://github.com/databricks/databricks-vscode).
> This is **not** an official Databricks extension.

---

## Table of Contents

1. [Requirements](#1-requirements)
2. [Configuration System](#2-configuration-system)
3. [Plugin Entry & Loading](#3-plugin-entry--loading)
4. [DAB Project Detection](#4-dab-project-detection)
5. [YAML Schema Injection (yamlls)](#5-yaml-schema-injection-yamlls)
6. [Spark Type Injection (pyright/basedpyright)](#6-spark-type-injection-pyrightbasedpyright)
7. [CLI Profile Resolution](#7-cli-profile-resolution)
8. [Virtualenv Support](#8-virtualenv-support)
9. [Command Framework](#9-command-framework)
10. [Deploy Command](#10-deploy-command)
11. [Run Command — Python](#11-run-command--python)
12. [Run Command — SQL](#12-run-command--sql)
13. [Terminal Split Utility](#13-terminal-split-utility)
14. [Output Buffer Utility](#14-output-buffer-utility)
15. [ANSI Color Rendering](#15-ansi-color-rendering)
16. [API Call Utility](#16-api-call-utility)
17. [State Refresh & External Integration](#17-state-refresh--external-integration)
18. [Test Suite](#18-test-suite)
19. [Documentation](#19-documentation)
20. [CI/CD](#20-cicd)
21. [Full File Listing with Responsibilities](#21-full-file-listing-with-responsibilities)

## Architectural Decisions

All decisions are documented in `docs/adr/*.md`. The key ones:

- **CLI as sole backend** — never call REST API directly from Lua; always go through `databricks` CLI
- **Subcommand pattern** — single `:Databricks` user command with per-subcommand parser + runner modules
- **DAB detection** — `databricks.yml` marker file, walked upward via `vim.fs.root`
- **YAML schema** — inject schema URL into yamlls via LspAttach
- **Terminal splits** — `termopen` for long-running commands, `vim.system` for short API calls

---

## 1. Requirements

- Neovim >= 0.12
- Databricks CLI (`databricks`) installed and authenticated on `$PATH`
- Optional: yaml-language-server (for YAML schema injection)
- Optional: pyright or basedpyright (for Spark type injection)
- Test framework: plenary.nvim

## 2. Configuration System

**File:** `lua/databricks/config.lua`

### Config Type Definitions

All types use LuaCATS annotations. The full config structure:

```lua
--- @class Databricks.SparkConfig
--- @field inject boolean  Default: true

--- @class Databricks.DABConfig
--- @field schema string|false|nil  Default: URL to Databricks bundle JS schema

--- @class Databricks.DeployCommandConfig
--- @field force boolean        Default: false
--- @field auto_approve boolean Default: false
--- @field target string|nil    Default: nil

--- @class Databricks.RunCommandConfig
--- @field cluster_id string|fun():string|nil   Fallback: $DATABRICKS_NVIM_CLUSTER_ID
--- @field warehouse_id string|fun():string|nil Fallback: $DATABRICKS_NVIM_WAREHOUSE_ID

--- @class Databricks.CommandsConfig
--- @field deploy Databricks.DeployCommandConfig
--- @field run    Databricks.RunCommandConfig

--- @class Databricks.Config
--- @field auto_detect boolean                Default: true
--- @field profile string|fun():string|nil     Fallback: $DATABRICKS_PROFILE
--- @field venv string|fun():string|nil        Fallback: $DATABRICKS_NVIM_VENV
--- @field verbose boolean                     Default: false
--- @field dab Databricks.DABConfig
--- @field commands Databricks.CommandsConfig
--- @field spark Databricks.SparkConfig
--- @field on_attach nil|fun():nil
```

### Defaults

```lua
{
  auto_detect = true,
  profile = nil,
  venv = nil,
  verbose = false,
  dab = {
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
      target = nil,
    },
    run = {
      cluster_id = nil,
      warehouse_id = nil,
    },
  },
  on_attach = nil,
  spark = {
    inject = true,
  },
}
```

### setup()

```lua
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("keep", opts, M.defaults)
end
```

Note: `"keep"` means user values take precedence but nil user values do NOT override defaults.

### Environment Variables

| Variable | Config field | Description |
|---|---|---|
| `DATABRICKS_PROFILE` | `profile` | Databricks CLI profile name |
| `DATABRICKS_NVIM_VENV` | `venv` | Path to Python virtualenv |
| `DATABRICKS_NVIM_CLUSTER_ID` | `commands.run.cluster_id` | Cluster ID for Python execution |
| `DATABRICKS_NVIM_WAREHOUSE_ID` | `commands.run.warehouse_id` | SQL warehouse ID |

### Resolution Pattern (used everywhere)

Priority order: CLI flag override > function() > env var > config string > nil

Implementation in `_commands/utils.lua`:

```lua
function M.resolve(value, env_var, override)
  if override ~= nil then return override end
  if type(value) == "function" then return value() end
  local from_env = vim.env[env_var]
  if from_env and from_env ~= "" then return from_env end
  if type(value) == "string" then return value end
  return nil
end
```

## 3. Plugin Entry & Loading

### Plugin File

**File:** `plugin/databricks.lua`

```lua
if not vim.g.databricks_loaded then
  require("databricks").setup()
  -- Create :Databricks user command
  vim.g.databricks_loaded = 1
end
```

Guard prevents double-loading. Calls `setup()` with no args (user-provided opts come from lazy.nvim's `opts` or manual `require("databricks").setup(opts)`).

### Main Module

**File:** `lua/databricks/init.lua`

```lua
local databricks = {}
databricks.config = require("databricks.config")
databricks.dab = require("databricks.dab")
databricks.profile = require("databricks.profile")
databricks.schema = require("databricks.schema")
databricks.spark = require("databricks.spark")

function databricks.refresh()
  vim.g.databricks_dab = databricks.dab.is_dab_project() and 1 or nil
  vim.g.databricks_profile = databricks.profile.resolve()
  vim.g.databricks_run_state = vim.g.databricks_run_state or "idle"
end

function databricks.setup(opts)
  databricks.config.setup(opts)
  databricks.schema.inject()
  databricks.spark.inject()
  databricks.refresh()
  -- Auto-detect on DirChanged/BufEnter
  if cfg.auto_detect then
    vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
      group = augroup("DatabricksAuto"),
      callback = function() databricks.refresh() end,
    })
  end
  -- on_attach callback
  if cfg.on_attach then cfg.on_attach() end
end
```

### Entry shim

**File:** `lua/databricks.lua`

```lua
return require("databricks.init")
```

## 4. DAB Project Detection

**File:** `lua/databricks/dab.lua`

Detects Databricks Asset Bundle projects by finding `databricks.yml` in the directory hierarchy.

### API

```lua
dab.is_dab_root(dir)    --> boolean          -- checks if dir contains databricks.yml
dab.find_root(path)     --> string|nil       -- walks upward from path, returns root dir
dab.is_dab_project(path) --> boolean         -- wrapper around find_root
```

### Implementation

- Uses `vim.uv.fs_stat()` to check for file existence
- Uses `vim.fs.root(path, "databricks.yml")` for upward walking (built-in Neovim 0.10+)
- `find_root` defaults to `vim.fn.getcwd()` when no path given
- The marker filename is hardcoded as `"databricks.yml"` — not configurable (matches CLI convention)

## 5. YAML Schema Injection (yamlls)

**File:** `lua/databricks/schema.lua`

Automatically pushes the Databricks bundle JSON Schema into yaml-language-server so that `databricks.yml` files get autocompletion and validation.

### Behavior

- **On setup**: creates `LspAttach` autocmd in augroup `"DatabricksSchema"`
- When a yamlls client attaches, calls `inject_into_client(client, schema_url)`
- Also pushes to any *already-attached* yamlls clients (loop over `vim.lsp.get_clients()`)
- When `schema` config is `false` or `nil`: deletes the augroup and does nothing

### inject_into_client(client, schema_url)

```lua
-- Gets current yaml schemas from client config
local settings = vim.tbl_get(client.config, "settings", "yaml", "schemas") or {}
-- Sets the schema URL to apply to databricks.yml
settings[schema_url] = "databricks.yml"
-- Merges and notifies client
client.config.settings = vim.tbl_deep_extend("force", ..., {
  yaml = { schemas = settings },
})
client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
```

### remove_from_client(client, schema_url)

Removes the schema URL from the client's settings and notifies.

## 6. Spark Type Injection (pyright/basedpyright)

**File:** `lua/databricks/spark.lua`

Injects `spark: SparkSession` type declaration into Python buffers so that pyright/basedpyright autocompletes Spark APIs.

### How It Works

1. **Find pyright's builtins.pyi**: searches:
   - Mason packages (`pyright` and `basedpyright`)
   - `pyright-langserver` on PATH
2. **Read the real builtins.pyi**, append `SPARK_STUB` string
3. **Write merged file** to Neovim cache dir: `stdpath("cache")/databricks/stubs/builtins.pyi`
4. **Skip write if unchanged** (compares content)
5. **Configure LSP**: uses `vim.lsp.config(name, { settings = ... })` for Neovim >= 0.11
6. **Push to already-attached clients** via `workspace/didChangeConfiguration`
7. **Register LspAttach** for future clients

### The Spark Stub

```lua
local SPARK_STUB = "\nfrom pyspark.sql import SparkSession\nspark: SparkSession\n"
```

### Cleanup

When `spark.inject` is `false`:
- Deletes the `"DatabricksSpark"` augroup
- Removes `stubPath` from all running pyright/basedpyright clients

## 7. CLI Profile Resolution

**File:** `lua/databricks/profile.lua`

Resolves the Databricks CLI profile to use with the `--profile` flag.

```lua
function M.resolve()
  return M._resolve(config.config.profile, "DATABRICKS_PROFILE")
end
```

Resolution order:
1. If config is a function → call it
2. If `DATABRICKS_PROFILE` env var is set → use it
3. If config is a string → use it
4. Otherwise → nil (CLI uses default profile)

## 8. Virtualenv Support

Handled in `_commands/utils.lua` via `build_env()`.

When a venv is configured (config `venv` field, function, or `DATABRICKS_NVIM_VENV`):
- Sets `VIRTUAL_ENV` env var
- Prepends `venv/bin` to `PATH`

Used for all CLI invocations (both `termopen` and `vim.system`).

Caches the base environment (`vim.fn.environ()`) on first call for safety in timer/job callbacks (fast context).

## 9. Command Framework

**File:** `lua/databricks/_commands/init.lua`

### User Command

```lua
vim.api.nvim_create_user_command("Databricks", function(opts)
  require("databricks._commands").handle(opts.fargs)
end, {
  nargs = "*",
  complete = "customlist,v:lua.require'databricks._commands'.complete",
  desc = "Databricks CLI commands (deploy, run)",
})
```

### Subcommand Registry

```lua
local subcommands = {
  deploy = require("databricks._commands.deploy.parser"),
  run    = require("databricks._commands.run.parser"),
}
```

Each entry must implement:
- `parse(args) → opts|nil` — parses CLI args, returns structured opts table (nil on error)
- `help() → string` — returns help text for listing

### Dispatcher

1. No args → list all commands with their help strings
2. Unknown subcommand → error notification
3. Known subcommand → `parse(args)`, then `require("_commands.<name>.runner").run(opts)`

### Tab Completion

Completes subcommand names from the registry.

## 10. Deploy Command

### Parser

**File:** `lua/databricks/_commands/deploy/parser.lua`

Parses into `Databricks.DeployOpts`:
```lua
--- @class Databricks.DeployOpts
--- @field force boolean
--- @field auto_approve boolean
--- @field target string|nil
```

Flags: `--force`, `--auto-approve`, `--target <name>`
- `--target` requires a non-flag value following it
- Unknown flags → nil + error notification

### Runner

**File:** `lua/databricks/_commands/deploy/runner.lua`

1. Guard: must be inside a DAB project (calls `dab.is_dab_project()`)
2. Merge CLI flags with config defaults (`utils.merge_flags`)
3. Build command: `databricks bundle deploy [--force] [--auto-approve] [--target <name>]`
4. Run via `utils.run_terminal()` with:
   - `name = "Deploy"`
   - `cwd = dab.find_root()`
   - `on_exit`: success notification (exit 0) or error notification (non-zero)

## 11. Run Command — Python

### Parser

**File:** `lua/databricks/_commands/run/parser.lua`

Parses into `Databricks.RunOpts`:
```lua
--- @class Databricks.RunOpts
--- @field language "python"|"sql"
--- @field code string         -- file contents or visual selection
--- @field cluster_id string|nil   -- CLI override
--- @field warehouse_id string|nil -- CLI override
```

**Code extraction logic:**
1. Check previous mode (`vim.fn.mode(1)`) — if visual (`v`, `V`, `^V`):
   - Get `<` and `>` marks for line range
   - For character-wise visual (`v`) on a single line, trim to column range
   - Concatenate selected lines
2. Fallback: read entire buffer
3. Detect language from `vim.bo.filetype` (only `python` and `sql` supported)

**Flags:** `--cluster-id <id>`, `--warehouse-id <id>`

### Runner

**File:** `lua/databricks/_commands/run/runner.lua`

Resolves cluster_id and warehouse_id, then dispatches to either `python.run()` or `sql.run()`.

### Python Runner

**File:** `lua/databricks/_commands/run/python.lua`

Async workflow via successive API calls:

```
run(code, cluster_id)
  → cluster.ensure_running(cluster_id, callback, error_callback)
    → step_create_context(s)
      → POST /api/1.2/contexts/create {clusterId, language:"python"}
        → step_execute(s)
          → POST /api/1.2/commands/execute {clusterId, contextId, language:"python", command}
            → step_start_polling(s)
              → timer every 5s → step_poll(s)
                → GET /api/1.2/commands/status?clusterId&contextId&commandId
                  → "Finished" → step_handle_result → destroy context
                  → "Error"/"Cancelled" → error → destroy context
```

Key details:
- Context is created and destroyed per execution
- Polling via `vim.fn.timer_start` (5s interval, repeats)
- Results handling: `text` → write data, `error` → show summary+cause, other → `vim.inspect`
- Timer wraps in `vim.schedule` because we're in a `vim.system` callback (fast context)
- Timing: logs duration in seconds using `vim.uv.hrtime()`
- State management via `u.set_state("idle"|"running"|"error")`

### Cluster Manager

**File:** `lua/databricks/_commands/run/cluster.lua`

Ensures a cluster is RUNNING before executing code:

```
ensure_running(cluster_id, on_ready, on_error)
  → check()
    → GET /api/2.0/clusters/get?cluster_id=
      → "RUNNING" → on_ready()
      → "ERROR" → on_error()
      → "TERMINATED" → start_cluster()
      → other (PENDING, RESIZING, etc.) → schedule_poll()
  → start_cluster()
    → POST /api/2.0/clusters/start {cluster_id}
      → schedule_poll()
  → poll()
    → timer every 5s → GET cluster state
      → "RUNNING" → on_ready()
      → "ERROR" → on_error()
      → "TERMINATED" → start_cluster()
      → other → keep polling
```

## 12. Run Command — SQL

**File:** `lua/databricks/_commands/run/sql.lua`

Single-shot async API call:

```
run(code, warehouse_id)
  → POST /api/2.0/sql/statements
    --json '{"statement":"<escaped code>","warehouse_id":"<id>","wait_timeout":"30s","on_wait_timeout":"CONTINUE"}'
    → Success (status.state == "SUCCEEDED"):
        → tab-separated rows from data.result.data_array
        → log duration
        → set_state("idle")
    → Error:
        → show error state and message
        → set_state("error")
```

## 13. Terminal Split Utility

**File:** `lua/databricks/_commands/utils.lua`

### Functions

```lua
--- @class RunTerminalOpts
--- @field name string          -- Buffer display name
--- @field cmd string|string[]  -- Command to run
--- @field cwd string           -- Working directory
--- @field on_exit? fun(code: number)

utils.run_terminal(opts)
```

### _create_terminal_buffer(opts) → buf, win

1. Constructs buffer name: `"Databricks_" .. name`
2. Deletes existing buffer with same name (if any)
3. Creates new scratch buffer, sets name
4. Opens horizontal split: `botright 15split`
5. Window options: `winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"`, `number = false`, `signcolumn = "no"`, `statuscolumn = "  "`

### build_term_command(cmd, venv) → shell_cmd

Wraps command with a header line:

```
printf '%s\n' '<header>' '' && exec <command>
```

Header format (with venv):
```
\x1b[2m#\x1b[0m \x1b[2mvenv:\x1b[0m \x1b[36m<venv_path>\x1b[0m \x1b[2m|\x1b[0m <command>
```

Header format (without venv):
```
\x1b[2m#\x1b[0m <command>
```

### run_terminal(opts)

1. Creates terminal buffer
2. Builds env table with venv, sets `TERM=xterm-256color`
3. Builds shell command
4. Calls `vim.fn.termopen()` with `cwd`, `env`, `on_exit`
5. On exit code 0: auto-close window after 2.5s
6. On exit code != 0: window stays open
7. On job start failure: close window, show error notification

## 14. Output Buffer Utility

**File:** `lua/databricks/_commands/utils.lua`

### append_to_buffer(name, text, hl_group)

Used for `:Databricks run` output (not for terminal-style output).

- Creates buffer named `"Databricks_" .. name` on first use (same window styling as terminal)
- Appends text lines
- Applies optional highlight group to entire lines
- Scrolls to bottom
- All wrapped in `vim.schedule` for safe use from fast context (timer/system callbacks)

### append_ansi(name, text)

Same as above but:
- Parses ANSI SGR escape codes via `parse_ansi_segments()`
- Strips ANSI codes from text
- Applies per-segment highlights using `nvim_buf_add_highlight`

### parse_ansi_segments(line) → {text, hl}[]

Parses a line with ANSI SGR sequences into segments. Maps ANSI color codes (30-37, 90-97, 0, 1) to Neovim highlight groups via the colors module.

## 15. ANSI Color Rendering

**File:** `lua/databricks/colors.lua`

### Constants

```lua
M.dim = "\x1b[2m"
M.reset = "\x1b[0m"
M.cyan = "\x1b[36m"
```

### ANSI → Highlight Group Mapping

```lua
M.ansi_to_hl = {
  ["0"]  = false,       -- reset → default
  ["1"]  = "Bold",
  ["30"] = "Comment",
  ["31"] = "ErrorMsg",
  ["32"] = "String",
  ["33"] = "WarningMsg",
  ["34"] = "Special",
  ["35"] = "Constant",
  ["36"] = "Identifier",
  ["37"] = false,
  ["90"] = "Comment",   -- bright black (gray)
  ["91"] = "ErrorMsg",
  ["92"] = "String",
  ["93"] = "WarningMsg",
  ["94"] = "Special",
  ["95"] = "Constant",
  ["96"] = "Identifier",
  ["97"] = false,
}
```

`false` means "reset to default" (no highlight).
`nil` entries are ignored (keep current highlight).

## 16. API Call Utility

**File:** `lua/databricks/_commands/run/util.lua`

### api_call(api_args, on_ok, on_err)

Generic async API caller:

```lua
function M.api_call(api_args, on_ok, on_err)
  local cmd = utils.databricks_cmd(api_args)
  -- Verbose logging: append "  [verbose] <cmd>" to output buffer
  vim.system(cmd, { text = true, env = utils.build_env() }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then on_err(result.stderr) return end
      local data, err = parse_json(result.stdout)
      if not data then on_err(err) return end
      on_ok(data)
    end)
  end)
end
```

### parse_json(raw) → data|nil, err

- Tries `vim.json.decode` on trimmed string
- Falls back to extracting first `{...}` block (handles CLI output with extra text)
- Handles nested braces correctly (depth tracking)

### Helper functions

```lua
M.log(msg)     -- append gray Comment line to "Run" buffer
M.write(msg)   -- append plain text to "Run" buffer
M.error(msg)   -- append red ErrorMsg line to "Run" buffer
M.set_state(s) -- vim.g.databricks_run_state = s
M.json_escape(s) -- escape string for JSON inclusion (quotes, backslashes, newlines, etc.)
```

## 17. State Refresh & External Integration

**File:** `lua/databricks/init.lua`

```lua
function databricks.refresh()
  vim.g.databricks_dab = databricks.dab.is_dab_project() and 1 or nil
  vim.g.databricks_profile = databricks.profile.resolve()
  vim.g.databricks_run_state = vim.g.databricks_run_state or "idle"
end
```

- Called on `setup()` and on `DirChanged`/`BufEnter` (when `auto_detect` enabled)
- `vim.g.databricks_dab` is 1 or nil (for conditional display in lualine)
- `vim.g.databricks_run_state` transitions: `"idle"` → `"running"` → `"idle"`/`"error"`
- Designed for lualine statusline integration (no actual lualine component provided)

## 18. Test Suite

**Framework:** Plenary Busted (Neovim headless)

**Test Init:** `tests/minimal_init.lua` — auto-clones plenary.nvim to `/tmp` if not found.

**Makefile:**
```makefile
TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

test:
	@nvim --headless --noplugin -u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"
```

### Tests (47 total)

| File | Tests | What it covers |
|---|---|---|
| `dab_spec.lua` | 7 | `is_dab_root`, `find_root` (subdir, missing, default cwd), `is_dab_project` |
| `profile_spec.lua` | 6 | String config, function config, env fallback, precedence rules, nil |
| `config_spec.lua` | 12 | Merging, empty opts, nil opts, partial override, all fields (venv, profile, cluster, warehouse) |
| `commands_config_spec.lua` | 6 | Deploy defaults, override, partial; run defaults, override |
| `deploy_parser_spec.lua` | 10 | All flags, combinations, missing values, unknown flags, help text |
| `run_parser_spec.lua` | 9 | Unsupported ft, flag parsing, unknown flag, missing values, file content capture (py+sql) |
| `utils_spec.lua` | 27 | `bufname`, `_create_terminal_buffer` (creation, cleanup, naming, window), `build_term_command` (table/string cmd, venv), `resolve` (all precedence levels), `build_env` (venv, env precedence), `merge_flags` |

## 19. Documentation

### Vimdoc

- Source: `doc/vimdoc.md` (includes `index.md`, `installation.md`, `configuration.md`, `commands.md`, `api.md`)
- Generated: `doc/databricks.txt` (via panvimdoc)
- Generation command: `make doc`

### ADR Files

`docs/adr/*.md`:

1. `0001-use-databricks-cli-as-backend.md` — CLI as sole backend
2. `0002-subcommand-pattern-for-user-commands.md` — `:Databricks <subcommand>` pattern
3. `0003-dab-project-detection-via-marker-file.md` — `databricks.yml` detection
4. `0004-yaml-schema-injection-via-yamlls.md` — Schema injection approach
5. `0005-terminal-split-for-command-output.md` — Terminal split for deploy, output buffer for run

## 20. CI/CD

### GitHub Workflows

| File | Trigger | Action |
|---|---|---|
| `.github/workflows/lint-test.yml` | push/PR | Run `make test` + stylua lint |
| `.github/workflows/release.yml` | release-please | Automated releases |
| `.github/workflows/panvimdoc.yaml` | push to main | Generate vimdoc |

### Config Files

- `.stylua.toml` — Lua formatting
- `release-please-config.json` + `.release-please-manifest.json` — release please
- `.github/dependabot.yml` — dependency updates
- `.github/FUNDING.yml` — sponsor link

## 21. Full File Listing with Responsibilities

```
databricks.nvim/
├── plugin/
│   └── databricks.lua              # Plugin entry: guard, setup(), :Databricks user command
├── lua/
│   ├── databricks.lua              # Module shim → require("databricks.init")
│   └── databricks/
│       ├── init.lua                # Main module: setup(), refresh(), submodule references
│       ├── config.lua              # Config types, defaults, setup(), merge logic
│       ├── dab.lua                 # DAB project detection (databricks.yml marker)
│       ├── profile.lua             # Profile resolution (config/fn/env)
│       ├── schema.lua              # YAML schema injection into yamlls
│       ├── spark.lua               # Spark Session stub injection into pyright
│       ├── colors.lua              # ANSI escape codes + SGR→Neovim highlight mapping
│       └── _commands/
│           ├── init.lua            # Command registry, dispatcher, tab-completion
│           ├── utils.lua           # Terminal/out buffers, env building, cmd builder,
│           │                       #   ANSI parsing, flag merging, resolve(), api_call()
│           ├── deploy/
│           │   ├── parser.lua      # Deploy CLI flag parsing
│           │   └── runner.lua      # Deploy execution via terminal split
│           └── run/
│               ├── parser.lua      # Run CLI flag parsing, code extraction, language detection
│               ├── runner.lua      # Run dispatch (Python vs SQL)
│               ├── python.lua      # Python: context creation, execute, poll, result
│               ├── sql.lua         # SQL: statement execution API
│               ├── cluster.lua     # Cluster state check, start, poll
│               └── util.lua        # Run-specific helpers (log/write/error/api_call/json)
├── tests/
│   ├── minimal_init.lua            # Test bootstrap (auto-clones plenary)
│   ├── dab_spec.lua                # DAB detection tests
│   ├── profile_spec.lua            # Profile resolution tests
│   ├── config_spec.lua             # Config merge tests
│   ├── commands_config_spec.lua    # Command config tests
│   ├── deploy_parser_spec.lua      # Deploy parser tests
│   ├── run_parser_spec.lua         # Run parser tests
│   └── utils_spec.lua              # Utility function tests
├── doc/
│   ├── databricks.txt              # Generated vimdoc
│   ├── vimdoc.md                   # Master doc include file
│   ├── index.md                    # Introduction + feature list
│   ├── installation.md             # Install instructions
│   ├── configuration.md            # Full config reference + env vars
│   ├── commands.md                 # :Databricks, deploy, run docs
│   └── api.md                      # Lua API reference
├── docs/
│   └── adr/                        # Architecture Decision Records
│       ├── 0001-use-databricks-cli-as-backend.md
│       ├── 0002-subcommand-pattern-for-user-commands.md
│       ├── 0003-dab-project-detection-via-marker-file.md
│       ├── 0004-yaml-schema-injection-via-yamlls.md
│       └── 0005-terminal-split-for-command-output.md
├── .github/workflows/
│   ├── lint-test.yml               # CI: lint + test
│   ├── release.yml                 # CD: release-please
│   └── panvimdoc.yaml              # Doc generation
├── README.md                       # Project overview
├── Makefile                        # test, doc targets
├── databricks.yml                  # Empty marker file (self-reference)
├── .stylua.toml                    # Lua formatter config
├── release-please-config.json      # Release automation config
├── .release-please-manifest.json   # Release version manifest
├── CONTRIBUTING.md                 # Contributing guidelines
├── test.yml                        # (appears to be unused/leftover)
└── a.py                            # (appears to be unused/leftover)
```
