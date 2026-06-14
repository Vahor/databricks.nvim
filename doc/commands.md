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
```
