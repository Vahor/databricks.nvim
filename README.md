# databricks.nvim

Neovim extension for Databricks. DAB project detection, YAML schema support, and statusline integration.

This is not an official Databricks extension.

> [!IMPORTANT]
> This is a work in progress. Please report issues or feature requests on [GitHub](https://github.com/vahor/databricks.nvim/issues).
> Config changes are to be expected.

See [doc/databricks.txt](doc/databricks.txt) for the full manual page.

## Features

- **DAB project detection** — Automatically detects [Declarative Automation Bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/) projects by finding `databricks.yml` in the workspace root.
- **YAML schema injection** — Hooks into `LspAttach` to give yaml-language-server the [Databricks bundle JSON Schema](https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json), enabling auto-completion and validation for `databricks.yml` files.

Uses the [Databricks CLI](https://github.com/databricks/cli) as backend.
Based on [Databricks VsCode extension](https://github.com/databricks/databricks-vscode)

### Planned

1. `:Databricks deploy` — run `databricks bundle deploy` in a terminal split (WIP)
2. `:Databricks validate` — run `databricks bundle validate`
3. Upload and run file on serverless or cluster
4. Lualine components
5. Inject `spark` type in python buffers

## Install

Neovim ≥ 0.12. Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'vahor/databricks.nvim',
  lazy = false,
  opts = {},
}
```

See `:help databricks` for configuration, API, and advanced usage.

## License

MIT
