# DAB project detection via `databricks.yml` marker file

A directory is identified as a DAB (Declarative Automation Bundle) project root when it contains a `databricks.yml` file. Detection walks upward from the buffer path or cwd, re-evaluating on `DirChanged` / `BufEnter`.

**Why:**

- **This is the Databricks convention.** The CLI itself treats `databricks.yml` as the bundle root. The VSCode extension activates on the same marker via `workspaceContains:**/databricks.yml`. Matching this means users get consistent behavior across editors.
- **Filename is not configurable.** The Databricks CLI does not support a `--file` flag to specify an alternative bundle filename. Making it configurable in the plugin would break the CLI integration (the CLI would still look for `databricks.yml`).
- **`vim.fs.root` walks upward efficiently.** Neovim 0.10+ provides this built-in — no manual recursion.
- **`auto_detect` is opt-out.** Disabling it lets users control detection manually (useful in multi-project workspaces or when they want explicit control).

**Rejected alternative:** Requiring user to explicitly set the project root in config. Too much friction for the common case.
