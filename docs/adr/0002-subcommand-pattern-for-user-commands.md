# `:Databricks <subcommand>` pattern with a lightweight custom parser

User-facing commands follow the pattern `:Databricks <subcommand> [args]`. A custom Lua parser dispatches to per-subcommand modules. No external parsing library.

**Why:**

- **Single entry point.** One `nvim_create_user_command` for tab-completion, help text, and discoverability. Adding a subcommand is one file + one entry in the registry table.
- **No external dependencies.** A ~50-line dispatcher with `nvim_create_user_command` built-in completion handles argument splitting, dispatch, and error reporting. Full arg parsing libraries (argparse, Penlight) are overkill for CLI wrapper commands where we mostly forward raw strings to `termopen`.
- **Matches VSCode's command palette model.** In VSCode, every action is `databricks.<category>.<action>`; in neovim it's `:Databricks <action>`. Same mental model, idiomatic for each editor.
- **Parser per subcommand.** Each subcommand has its own `parse(args)` function that returns a structured options table. This keeps parsing logic colocated with the command it serves, not centralized in a growing `if/elseif` chain.

**Considered option:** Flattened commands (`:DatabricksDeploy`, `:DatabricksValidate`). Rejected because it pollutes the command namespace and doesn't scale — adding 10 commands means 10 `nvim_create_user_command` calls and 10 completion functions.

**Consequences:**

- Subcommands are registered in `lua/databricks/_commands/init.lua` with a mapping table `{ name → parser_module }`.
- Adding a subcommand requires: (1) `_commands/<name>/parser.lua`, (2) `_commands/<name>/runner.lua`, (3) registering in the table.
