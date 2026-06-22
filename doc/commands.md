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
- Output is written to a persistent log file (default: `stdpath("data")/databricks.nvim/<project>/`).
  Configure the base directory via `log.dir` — see [Configuration](configuration.md).
  Logs are isolated per project: a subdirectory is created using the project root name.
- Log filenames encode the relative path from the project root (e.g. `src__lib_utils.py.log`
  for `src/lib/utils.py`) to disambiguate files with the same name in different directories.
- Opens a terminal showing tail logs of the execution
- Use `:Databricks log` to list and reopen past logs
```vim
:Databricks run
:Databricks run --cluster-id 1234-5678-abcdef
:Databricks run --warehouse-id abcd-efgh-ijkl
:'<,'>Databricks run
:3,10Databricks run
```

### Run output links

When executing code on a cluster or warehouse, the log output now includes a clickable link:
- **Python runs** — shows a cluster link after confirming the cluster is running
- **SQL runs** — shows a warehouse link when execution starts

The link is displayed as `Open in browser: <url>` in the run log terminal.


## `:Databricks log`

List past run log files in a telescope picker.

```vim
:Databricks log
```

## `:Databricks resources`

Browse DAB resources (jobs, pipelines, dashboards, schemas, volumes, etc.) in a telescope picker.

- Requires being inside a DAB project
- Resources are discovered by running `databricks bundle summary --include-locations`
- Results are cached in memory and invalidated when bundle YAML files change
- Use `--refresh` to bypass the cache and pull remote state with `--force-pull`
- Press `<C-g>` in the picker to cycle grouping modes: **by type** (default), **by dir**, **by name**
- Select a resource to open its source YAML file at the definition line
- Press `<C-o>` to open a deployed resource (jobs, pipelines) in the browser. Host is resolved from `databricks auth describe`, falling back to `$DATABRICKS_HOST`

```vim
:Databricks resources
:Databricks resources --target dev
:Databricks resources --refresh
```

## `:Databricks refresh`

Re-fetch Unity Catalog metadata from Databricks and update the disk cache.

Useful when catalogs, schemas, or tables have changed since the last fetch (which happens automatically on first setup).

```vim
:Databricks refresh
```

## `:Databricks variables`

Browse DAB variables (user-defined and built-in) in a telescope picker.

- Requires being inside a DAB project
- Variables are discovered by running `databricks bundle summary --output json`
- Results are cached in memory and invalidated when bundle YAML files change
- Use `--refresh` to bypass the cache
- Requires [yq](https://github.com/mikefarah/yq) to resolve bundle YAML includes
- Select a variable to yank its name (`"` and `+` registers)
- Press `<C-y>` to yank without closing the picker
- Built-in variables (`bundle.*`, `workspace.*`) are listed automatically

```vim
:Databricks variables
:Databricks variables --target dev
:Databricks variables --refresh
```

