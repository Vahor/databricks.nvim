# Contributing to databricks.nvim

## Getting Started

### Prerequisites

- **Neovim ≥ 0.12**

### Development Setup

1. Fork and clone:
   ```bash
   git clone https://github.com/vahor/databricks.nvim.git
   cd databricks.nvim
   ```

2. Run tests:
   ```bash
   make test
   ```

## Project Structure

```
lua/databricks/
├── init.lua         # Entry point, setup(), refresh()
├── config.lua       # Configuration defaults
├── dab.lua          # DAB project detection
├── profile.lua      # Databricks CLI profile resolution
└── schema.lua       # YAML schema injection for yamlls
plugin/
└── databricks.lua   # Plugin bootstrap
tests/
├── minimal_init.lua # Test bootstrap
├── config_spec.lua
├── dab_spec.lua
└── profile_spec.lua
```

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Add tests for new functionality
4. Update the README if adding configuration or API changes
5. Ensure `make test` passes
6. Use [conventional commits](https://www.conventionalcommits.org/) — releases are automated via release-please

## Commit Convention

We use conventional commits for automated changelogs and versioning:

- `feat:` — new feature (bumps minor)
- `fix:` — bug fix (bumps patch)
- `docs:` — documentation only
- `chore:` — maintenance, CI, deps
- `refactor:` — code change that neither fixes nor adds a feature

Examples:
```
feat: add auto-deploy on save for DAB projects
fix: schema injection not working on BufEnter
docs: update configuration table in README
```

## Release Process

Releases are automated via [release-please](https://github.com/googleapis/release-please). Merging to `main` with conventional commits triggers a release PR. Merging that PR cuts a GitHub release.
