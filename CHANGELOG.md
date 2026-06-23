# Changelog

## [0.5.0](https://github.com/Vahor/databricks.nvim/compare/v0.4.0...v0.5.0) (2026-06-23)


### Features

* add blink sql completion ([#29](https://github.com/Vahor/databricks.nvim/issues/29)) ([e7082b1](https://github.com/Vahor/databricks.nvim/commit/e7082b1299ae95c949c4dc1f35455e81fa909745))
* add quotes around string values ([#40](https://github.com/Vahor/databricks.nvim/issues/40)) ([6654ac2](https://github.com/Vahor/databricks.nvim/commit/6654ac220ac0127ef565ee615cb3a5c1cb7ef123))
* cache bundle summary for faster resources/variables commands ([#36](https://github.com/Vahor/databricks.nvim/issues/36)) ([755afa6](https://github.com/Vahor/databricks.nvim/commit/755afa60c53049a845f628f883f711983eddf006))


### Bug Fixes

* address bugs and code smells from full codebase review ([#39](https://github.com/Vahor/databricks.nvim/issues/39)) ([8c42415](https://github.com/Vahor/databricks.nvim/commit/8c42415e85ab49ee565c2c0b24622089f585300f))
* also schedule toggle_inject in check_async callback path ([6816667](https://github.com/Vahor/databricks.nvim/commit/6816667aa809fe20b898f2e0d61aae09b7f68af2))
* replace vim.fn.mkdir with vim.uv ([be21af1](https://github.com/Vahor/databricks.nvim/commit/be21af1acab2d60c27f7a784561931e2603d0b91))
* skip plugin setup when databricks auth fails ([#32](https://github.com/Vahor/databricks.nvim/issues/32)) ([1025ffb](https://github.com/Vahor/databricks.nvim/commit/1025ffbfe52425ca14f6515786654665f85e3974))
* wrap toggle_inject in vim.schedule to avoid fast-event error ([d1e7b3b](https://github.com/Vahor/databricks.nvim/commit/d1e7b3b0c17d6084e4efe7b34ddc70461194d78a))

## [0.4.0](https://github.com/Vahor/databricks.nvim/compare/v0.3.0...v0.4.0) (2026-06-21)


### Features

* add "open" option for logs, to open script file ([7b34ff5](https://github.com/Vahor/databricks.nvim/commit/7b34ff512cade251e1132b921ad244159ace1dcb))
* add a way to toggle injection, and enable only on dab projects ([8e423cf](https://github.com/Vahor/databricks.nvim/commit/8e423cfd4a262e8fb57fe4fbd56c440e0a620e1c))
* add resources picker ([#18](https://github.com/Vahor/databricks.nvim/issues/18)) ([c4e002c](https://github.com/Vahor/databricks.nvim/commit/c4e002c97c22cb3c245558bdabf1d2ea831a6154))
* add variables viewer ([#21](https://github.com/Vahor/databricks.nvim/issues/21)) ([fe027bf](https://github.com/Vahor/databricks.nvim/commit/fe027bf420150a254a90b81021d1fde662f163e9))
* make log dir configurable and disambiguate log filenames ([#17](https://github.com/Vahor/databricks.nvim/issues/17)) ([7995ce1](https://github.com/Vahor/databricks.nvim/commit/7995ce1235cf181b28401300e9e1dbce62e64a9e))
* open to web ([#19](https://github.com/Vahor/databricks.nvim/issues/19)) ([f5b844b](https://github.com/Vahor/databricks.nvim/commit/f5b844b26e4c78c7c72336bc159bd8e09c86ed44))
* replace config.dab.patterns with databricks.yml include list ([#28](https://github.com/Vahor/databricks.nvim/issues/28)) ([c456341](https://github.com/Vahor/databricks.nvim/commit/c4563412b49b9196a4d5819a5cbf5385d21b29ac))
* resolve default variables ([#24](https://github.com/Vahor/databricks.nvim/issues/24)) ([68e25b3](https://github.com/Vahor/databricks.nvim/commit/68e25b3cf232ad8431324e5487e57028e9462809))
* use vim.ui.select in log command ([#16](https://github.com/Vahor/databricks.nvim/issues/16)) ([7d9c1c7](https://github.com/Vahor/databricks.nvim/commit/7d9c1c70b2a1085d9f6a8794923d00a41bcc0040))

## [0.3.0](https://github.com/Vahor/databricks.nvim/compare/v0.2.0...v0.3.0) (2026-06-19)


### Features

* add configurable patterns for yaml schema injection ([6bec8f8](https://github.com/Vahor/databricks.nvim/commit/6bec8f8add0cc6a0c0bff8d53d7e51349142c224))


### Bug Fixes

* avoid table reference corruption in yaml schema injection ([23717f8](https://github.com/Vahor/databricks.nvim/commit/23717f8014c50992f6f69d103b2826ed719c7486))
* update yamlls insteadof using lsp attack hook ([66b38fb](https://github.com/Vahor/databricks.nvim/commit/66b38fb350261f87638cb7cc14902f31df8f7f9f))

## [0.2.0](https://github.com/Vahor/databricks.nvim/compare/v0.1.0...v0.2.0) (2026-06-19)


### Features

* add venv resolution ([c037660](https://github.com/Vahor/databricks.nvim/commit/c037660abc305476995c9dde29c4c90b86dba47f))
