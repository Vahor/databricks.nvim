# Commands

## `:Databricks`

Without a subcommand, lists all available commands:

```vim
:Databricks
" databricks.nvim -- available commands:
"   deploy  Run `databricks bundle deploy` in a terminal split
"   run     Run current Python or SQL file (or visual selection) on Databricks
```

## `:Databricks deploy`

Run `databricks bundle deploy` in a terminal split.

- Requires being inside a DAB project (directory containing `databricks.yml`)
- Opens a small horizontal terminal at the bottom
- On success (exit 0): auto-closes with confirmation notification
- On failure: stays open for inspection

```vim
:Databricks deploy
:Databricks deploy --force --target dev
:Databricks deploy --auto-approve --target prod
```

## `:Databricks run`

Execute current Python or SQL file (or visual selection) on a Databricks cluster or SQL warehouse.

- Auto-detects language from buffer filetype (`python` or `sql`)
- Visual selection sends only selected lines
- Opens an output buffer at the bottom
- Runs asynchronously
- Status exposed via `vim.g.databricks_run_state`

```vim
:Databricks run
:Databricks run --cluster-id 1234-5678-abcdef
:Databricks run --warehouse-id abcd-efgh-ijkl
```
