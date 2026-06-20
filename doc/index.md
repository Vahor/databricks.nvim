# Introduction

**This is not an official Databricks extension.**

## Features

- **DAB project detection** — Automatically detects Databricks Asset Bundle projects by finding `databricks.yml` in the workspace root.
- **YAML schema injection** — Hooks into `LspAttach` to give yaml-language-server the Databricks bundle JSON Schema, enabling auto-completion and validation for `databricks.yml` files.
- **Spark type injection** — Injects the `spark` type into Python buffers via pyright stubs, giving auto-completion on the `SparkSession` object.
- **Run Python/SQL** — Execute current file or visual selection on a Databricks cluster or SQL warehouse via `:Databricks run`.
- **Deploy DAB projects** — Run `databricks bundle deploy` in a terminal split via `:Databricks deploy`.
- **DAB Resource Explorer** — Browse and open DAB resources (jobs, pipelines, dashboards, etc.) via `:Databricks resources` with a telescope picker grouped by type, directory, or name.
- **Run Logs** — Browse and open past run log files with telescope or `vim.ui.select` via `:Databricks log`.

Using [Databricks CLI](https://github.com/databricks/cli) as the backend.
