# Terminal split for command output

Long-running CLI commands (deploy, validate, sync) run in a `vim.fn.termopen()` inside a horizontal split at the bottom of the window. The split auto-closes on success (exit 0) and stays open on failure.

**Why:**

- **Real-time streaming.** `termopen` pipes stdout/stderr directly to a terminal buffer — the user sees `databricks bundle deploy` logs as they happen, with ANSI colors preserved. Quickfix or floating windows can't stream.
- **Interactive on failure.** When a command fails, the terminal stays open so the user can scroll through the full output, copy error messages, and fix the issue without losing context.
- **Non-blocking.** `termopen` runs asynchronously. The user can continue editing while a deploy runs.
- **No complex output parsing.** We don't need to parse CLI output into structured diagnostics. The terminal shows it raw, which is what the user would see in a shell anyway. Lower maintenance burden.
- **Matches VSCode's terminal-based approach.** The VSCode extension runs bundle commands in a VS Code terminal, with similar auto-close/hold behavior.

**Rejected alternatives:**

- **Quickfix list:** Not suitable for streaming output. Quickfix expects complete results, not incremental logs. Also loses ANSI colors.
- **Floating window:** Same streaming limitation. Harder to scroll. Also visually transient — the user might miss output that scrolls past.
- **`vim.system` / `vim.fn.jobstart` without a terminal:** Captures output but can't display it incrementally. Blocking (unless using callbacks), and requires manual buffer management.
- **`:!command`:** Blocking, no output capture, clunky.

**Consequences:**

- The terminal utility function (`run_terminal`) is generic — any subcommand runner calls it with `{ cmd, cwd }`.
- The buffer is named by convention (e.g., `[Databricks Deploy]`) with `bufhidden = "wipe"` for cleanup.
- Exit code handling is done via `on_exit` callback in the runner, not in the utility.
