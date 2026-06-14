# Use the `databricks` CLI as the sole backend

All interaction with Databricks (auth, deploy, sync, run) goes through the `databricks` CLI binary. We do not call the Databricks REST API directly from Lua.

**Why:**

- **Auth is solved.** The CLI manages OAuth, PATs, profiles via `.databrickscfg`, and environment variables. We inherit all of it for free — no auth code in neovim.
- **Feature parity with the CLI.** Every `databricks bundle *` and `databricks workspace *` command added upstream becomes available without an SDK wrapper.
- **Single binary dependency.** Users already have the CLI installed. No HTTP client, no JSON parsing of REST responses, no SDK versioning to track.
- **Matches VSCode's pattern.** The VSCode extension also shells out to the CLI for bundle operations (`deploy`, `destroy`, `validate`, `sync`). They only use the SDK for execution contexts and workspace FS — things the CLI doesn't expose interactively.

**Rejected alternative:** Calling the Databricks REST API via the experimental TypeScript SDK (`@databricks/sdk-experimental`). This is what the VSCode extension uses for interactive execution (upload + run file, cell execution). It gives real-time output streaming and fine-grained error handling, but requires implementing auth, HTTP, and execution context management — unjustified when the CLI covers the core workflows.

If the CLI proves insufficient for a future feature (e.g., no single command to upload and run a notebook), we will evaluate a lightweight SDK integration at that point, scoped to that feature only.
