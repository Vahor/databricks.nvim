local M = {}

local ANSI_ESC = string.char(27)

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

--- Parse a line with ANSI SGR codes into {text, hl} segments.
--- @param line string
--- @return table[] segments
function M.parse_ansi_segments(line)
  local segments = {}
  local pos = 1
  local current_hl = nil

  while pos <= #line do
    local esc_start = line:find(ANSI_ESC .. "[", pos, true)
    if not esc_start then
      table.insert(segments, { text = line:sub(pos), hl = current_hl })
      break
    end
    if esc_start > pos then
      table.insert(segments, { text = line:sub(pos, esc_start - 1), hl = current_hl })
    end
    local esc_end = line:find("m", esc_start, true)
    if not esc_end then
      table.insert(segments, { text = line:sub(pos), hl = current_hl })
      break
    end
    local codes_str = line:sub(esc_start + 2, esc_end - 1)
    for code in codes_str:gmatch("[0-9]+") do
      local mapped = M.ansi_to_hl[code]
      if mapped == false then
        current_hl = nil
      elseif mapped then
        current_hl = mapped
      end
    end
    pos = esc_end + 1
  end

  return segments
end

return M
