--- ANSI escape codes for terminal output.
--- Used by build_term_command for the header line in terminal splits.

local M = {}

M.dim = "\x1b[2m"
M.reset = "\x1b[0m"
M.cyan = "\x1b[36m"

--- Wrap text in dim (gray) escape codes.
function M.gray(text)
  return M.dim .. text .. M.reset
end

--- Map ANSI SGR color codes to Neovim highlight groups.
--- nil = keep applying, false = reset to default.
M.ansi_to_hl = {
  ["0"] = false,
  ["1"] = "Bold",
  ["30"] = "Comment",
  ["31"] = "ErrorMsg",
  ["32"] = "String",
  ["33"] = "WarningMsg",
  ["34"] = "Special",
  ["35"] = "Constant",
  ["36"] = "Identifier",
  ["37"] = false,
  ["90"] = "Comment",
  ["91"] = "ErrorMsg",
  ["92"] = "String",
  ["93"] = "WarningMsg",
  ["94"] = "Special",
  ["95"] = "Constant",
  ["96"] = "Identifier",
  ["97"] = false,
}

return M
