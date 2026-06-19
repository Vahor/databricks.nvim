# Contributing to databricks.nvim

## Getting Started

- **Neovim >= 0.12**
- **Databricks CLI** (`databricks`) installed and authenticated on `$PATH`

1. Fork and clone the repo
2. Install dev dependencies: `make deps` (clones plenary.nvim for tests)
3. Run tests: `make test`
4. Format code: `stylua .`
5. Use conventional commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`)

### Pull Requests

- Keep PRs focused on a single concern
- Include or update tests in `tests/`
- Verify `make test` passes before submitting

## Releases

Releases are automated via release-please. The CI generates changelogs from conventional commit messages.
