# Introduction

**This is not an official Databricks extension.**

## Features

- **DAB project detection** — Automatically detects [Declarative Automation Bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/) projects by finding `databricks.yml` in the workspace root.
- **YAML schema injection** — Hooks into `LspAttach` to give yaml-language-server the [Databricks bundle JSON Schema](https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json), enabling auto-completion and validation for `databricks.yml` files.
- **Spark type injection** — Injects the `spark` type into Python buffers via pyright stubs, giving auto-completion on the `SparkSession` object (matching the Databricks notebook environment).

Using [Databricks CLI](https://github.com/databricks/cli) as the backend.
