# Commands

## `:Databricks deploy`

Run `databricks bundle deploy` in a terminal split.

- Requires being inside a DAB project (a directory containing `databricks.yml`)
- Opens a small horizontal terminal at the bottom of the window
- On success (exit code 0): the terminal auto-closes and a confirmation notification is shown
- On failure (non-zero exit): the terminal stays open so you can inspect the error output

```vim
" Deploy the current DAB project
:Databricks deploy

" Deploy with flags
:Databricks deploy --force --target dev
:Databricks deploy --auto-approve --target prod
```

> [!NOTE]
> Requires the [Databricks CLI](https://github.com/databricks/cli) (`databricks`) to be installed and on your `$PATH`.
> Default flags can be set in config: `commands.deploy = { force = true, target = "dev" }`

## `:Databricks`

Without a subcommand, lists all available commands:

```vim
:Databricks
" databricks.nvim — available commands:
"   deploy  Run `databricks bundle deploy` in a terminal split
"   run     Run current Python or SQL file (or visual selection) on Databricks
```

## `:Databricks run`

Execute the current Python or SQL file (or a visual selection) on a Databricks cluster or SQL warehouse.

- Auto-detects language from buffer filetype (`python` or `sql`)
- If a visual selection is active, only the selected lines are sent
- Opens an output buffer at the bottom of the window
- Runs asynchronously — you can continue editing while it executes
- Status is exposed via `vim.g.databricks_run_state` for lualine integration

```vim
" Run the current file
:Databricks run

" Run with explicit cluster/warehouse override
:Databricks run --cluster-id 1234-5678-abcdef
:Databricks run --warehouse-id abcd-efgh-ijkl
```

> [!NOTE]
> Requires `commands.run.cluster_id` (for Python) and/or `commands.run.warehouse_id` (for SQL) to be set in config.
> Uses the [Databricks REST API](https://docs.databricks.com/api/workspace/commandexecution) under the hood via `databricks api`.
