# databricks.nvim

Neovim extension for Databricks. DAB project detection, YAML schema support, and statusline integration.

This is not an official Databricks extension.

> [!IMPORTANT]
> This is a work in progress. Please report issues or feature requests on [GitHub](https://github.com/vahor/databricks.nvim/issues).

See [doc/databricks.txt](doc/databricks.txt) for the full manual page.

## Features

- **DAB project detection** — Automatically detects Databricks Asset Bundle projects by finding `databricks.yml` in the workspace root.
- **YAML schema injection** — Pre-configures yamlls via `vim.lsp.config` with the Databricks bundle JSON Schema, enabling auto-completion and validation for `databricks.yml` files.
- **Spark type injection** — Injects the `spark` type into Python buffers via pyright stubs, giving auto-completion on the `SparkSession` object.
- **Run Python/SQL** — Execute code on a Databricks cluster or SQL warehouse via `:Databricks run`. Supports visual selection (`:'<,'>Databricks run`) and line ranges (`:3,10Databricks run`).
- **Deploy DAB projects** — Run `databricks bundle deploy` in a terminal split via `:Databricks deploy`.
- **DAB Variable Viewer** — Browse and inspect bundle variables, their values, and defaults in a telescope picker via `:Databricks variables`.
- **DAB Resource Explorer** — Browse and open DAB resources (jobs, pipelines, dashboards, etc.) grouped by type, directory, or name via `:Databricks resources` with a telescope picker.
- **Run Logs** — Browse and open past run log files via `:Databricks log`.

Uses the [Databricks CLI](https://github.com/databricks/cli) as backend. Requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for the resource explorer and log picker. Requires [yq](https://github.com/mikefarah/yq) to resolve bundle YAML includes (for schema injection and variable discovery).

## Install

Neovim >= 0.12. Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'vahor/databricks.nvim',
  lazy = false,
  dependencies = { 'nvim-telescope/telescope.nvim' },
  opts = {},
}
```

## License

MIT
