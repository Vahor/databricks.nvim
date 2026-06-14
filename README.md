# databricks.nvim

Neovim extension for Databricks. DAB project detection, YAML schema support, and statusline integration.

This is not an official Databricks extension.

> [!IMPORTANT]
> This is a work in progress. Please report issues or feature requests on [GitHub](https://github.com/databricks.nvim/main/issues).
> Config changes are to be expected.

See [docs/databricks.txt] for the full manual page.

## Features

- **DAB project detection** — Automatically detects [Declarative Automation Bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/) projects by finding `databricks.yml` in the workspace root.
- **YAML schema injection** — Hooks into `LspAttach` to give yaml-language-server the [Databricks bundle JSON Schema](https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json), enabling auto-completion and validation for `databricks.yml` files.

Uses the [Databricks CLI](https://github.com/databricks/cli) as backend.

### Planned

1. Auto-deploy on save (soon)
2. Upload and run file on serverless or cluster (later)
3. Auto-validate on save (later)

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
