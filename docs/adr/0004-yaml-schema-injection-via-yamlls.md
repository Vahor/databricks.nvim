# YAML schema injection via yaml-language-server LSP integration

We hook into `LspAttach` to push the Databricks bundle JSON Schema URL into yaml-language-server's settings. This gives autocompletion and validation for `databricks.yml` inside neovim without a custom LSP or tree-sitter grammar.

**Why:**

- **Yamlls already solves the problem.** It supports JSON Schema validation natively. The Databricks CLI publishes a JSON Schema for bundles. The only thing needed is to tell yamlls "apply this schema to files named `databricks.yml`" — a single `workspace/didChangeConfiguration` notification.
- **Matches VSCode's approach.** The VSCode extension registers a custom YAML validation provider via `redhat.vscode-yaml`, which is yamlls under the hood. We do the same thing in neovim idiomatically.
- **No custom grammar needed.** Tree-sitter YAML handles syntax highlighting; yamlls handles semantic validation. We don't need to build or maintain a tree-sitter grammar for Databricks bundle syntax.
- **Schema source is configurable.** Users can point to a local file (e.g., after running `databricks bundle schema > schema.json`), the GitHub raw URL, or disable entirely (`schema = false`).

**Consequences:**

- Requires yaml-language-server to be installed and active. This is the common case for neovim users editing YAML.
- Only affects `databricks.yml`.
