local M = {}

-- Width of a line's leading whitespace in screen columns, so mixed tabs and
-- spaces compare correctly.
local function leading_columns(line, tabstop)
  local whitespace = line:match("^[ \t]*") or ""
  local columns = 0

  for i = 1, #whitespace do
    if whitespace:sub(i, i) == "\t" then
      columns = columns + (tabstop - (columns % tabstop))
    else
      columns = columns + 1
    end
  end

  return columns
end

-- Strips the common indentation so an indented block (a method body, a branch)
-- parses on its own. Blank lines are emptied, remaining indentation is
-- normalised to spaces.
function M.dedent(lines, tabstop)
  local columns = {}
  local min_indent

  for i, line in ipairs(lines) do
    if line:find("%S") then
      columns[i] = leading_columns(line, tabstop)
      min_indent = min_indent and math.min(min_indent, columns[i]) or columns[i]
    end
  end

  if not min_indent or min_indent == 0 then
    return lines
  end

  local result = {}

  for i, line in ipairs(lines) do
    if line:find("%S") then
      local content = line:gsub("^[ \t]*", "", 1)
      result[i] = string.rep(" ", columns[i] - min_indent) .. content
    else
      result[i] = ""
    end
  end

  return result
end

return M
