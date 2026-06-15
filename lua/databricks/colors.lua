local M = {}

M.dim = "\x1b[2m"
M.reset = "\x1b[0m"
M.cyan = "\x1b[36m"

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
