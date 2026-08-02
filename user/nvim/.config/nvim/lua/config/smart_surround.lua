local M = {}

-- Deliberately excludes <>, since those are usually comparison operators in code.
local open_to_close = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

local close_to_open = {
  [")"] = "(",
  ["]"] = "[",
  ["}"] = "{",
}

local quotes = {
  ['"'] = true,
  ["'"] = true,
  ["`"] = true,
}

local delimiters = {}
for left, right in pairs(open_to_close) do
  delimiters[left] = true
  delimiters[right] = true
end
for quote in pairs(quotes) do
  delimiters[quote] = true
end

local function make_context()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return { lines = lines, text = table.concat(lines, "\n") }
end

local function cursor_offset()
  local pos = vim.api.nvim_win_get_cursor(0)
  return vim.api.nvim_buf_get_offset(0, pos[1] - 1) + pos[2]
end

local function offset_to_position(ctx, offset)
  for row, line in ipairs(ctx.lines) do
    if offset <= #line then
      return row - 1, offset
    end
    offset = offset - #line - 1
  end

  local last_row = #ctx.lines - 1
  return last_row, #ctx.lines[last_row + 1]
end

local function pairs_in(text)
  local found, stack = {}, {}
  local active_quote
  local i = 1

  while i <= #text do
    local char = text:sub(i, i)
    local offset = i - 1

    if active_quote then
      if char == "\\" then
        i = i + 1
      elseif char == active_quote.char then
        found[#found + 1] = {
          open = active_quote.open,
          close = offset,
          open_char = char,
          close_char = char,
        }
        active_quote = nil
      end
    elseif quotes[char] then
      active_quote = { char = char, open = offset }
    elseif open_to_close[char] then
      stack[#stack + 1] = { char = char, open = offset }
    elseif close_to_open[char] then
      local top = stack[#stack]
      if top and open_to_close[top.char] == char then
        stack[#stack] = nil
        found[#found + 1] = {
          open = top.open,
          close = offset,
          open_char = top.char,
          close_char = char,
        }
      end
    end

    i = i + 1
  end

  return found
end

local function contains(pair, offset)
  return pair.open <= offset and offset <= pair.close
end

local function span(pair)
  return pair.close - pair.open
end

local function innermost_pair(found, offset)
  local best
  for _, pair in ipairs(found) do
    if contains(pair, offset) and (not best or span(pair) < span(best)) then
      best = pair
    end
  end
  return best
end

local function parent_pair(found, offset)
  local covering = {}
  for _, pair in ipairs(found) do
    if contains(pair, offset) then
      covering[#covering + 1] = pair
    end
  end

  table.sort(covering, function(a, b)
    return span(a) < span(b)
  end)

  return covering[2], covering[1]
end

local function next_pair(found, offset)
  local best
  for _, pair in ipairs(found) do
    if pair.open >= offset and (not best or pair.open < best.open) then
      best = pair
    end
  end
  return best
end

local function previous_pair(found, offset)
  local best
  for _, pair in ipairs(found) do
    if pair.close < offset and (not best or pair.close > best.close) then
      best = pair
    end
  end
  return best
end

local function erase(ctx, spans)
  local cursor_target = math.huge
  for _, range in ipairs(spans) do
    cursor_target = math.min(cursor_target, range.from)
  end

  table.sort(spans, function(a, b)
    return a.from > b.from
  end)

  for index, range in ipairs(spans) do
    if index > 1 then
      pcall(vim.cmd, "undojoin")
    end

    local sr, sc = offset_to_position(ctx, range.from)
    local er, ec = offset_to_position(ctx, range.to)
    vim.api.nvim_buf_set_text(0, sr, sc, er, ec, {})
  end

  local new_ctx = make_context()
  local row, col = offset_to_position(new_ctx, math.min(cursor_target, #new_ctx.text))
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

local function erase_pair(ctx, pair, prefix_start)
  erase(ctx, {
    { from = pair.close, to = pair.close + 1 },
    { from = prefix_start or pair.open, to = pair.open + 1 },
  })
end

local function exact_pair_at(found, offset)
  for _, pair in ipairs(found) do
    if pair.open == offset or pair.close == offset then
      return pair
    end
  end
end

local function matches_target(pair, target)
  if quotes[target] then
    return pair.open_char == target
  end
  if open_to_close[target] then
    return pair.open_char == target
  end
  if close_to_open[target] then
    return pair.close_char == target
  end
  return false
end

local function target_pair(found, offset, target)
  for _, pair in ipairs(found) do
    if matches_target(pair, target) and (pair.open == offset or pair.close == offset) then
      return pair
    end
  end

  local best
  for _, pair in ipairs(found) do
    if matches_target(pair, target) and contains(pair, offset) and (not best or span(pair) < span(best)) then
      best = pair
    end
  end
  if best then
    return best
  end

  for _, pair in ipairs(found) do
    if matches_target(pair, target) and pair.open >= offset and (not best or pair.open < best.open) then
      best = pair
    end
  end
  return best
end

local function word_before(text, opening)
  local before = text:sub(1, opening)
  local start, finish = before:find("[%a_][%w_%.:]*%s*$")
  return start and start - 1, finish
end

local function assignment_before(text, opening)
  local before = text:sub(1, opening)
  local start, finish = before:find("[%a_][%w_%.:]*%s*=%s*$")
  return start and start - 1, finish
end

local function wrapper_at_cursor(ctx, found, offset)
  local best

  for _, pair in ipairs(found) do
    local start, finish
    if open_to_close[pair.open_char] then
      start, finish = word_before(ctx.text, pair.open)
    elseif quotes[pair.open_char] then
      start, finish = assignment_before(ctx.text, pair.open)
    end

    if start and offset >= start and offset < finish then
      if not best or pair.open < best.pair.open then
        best = { pair = pair, prefix_start = start }
      end
    end
  end

  return best
end

function M.delete_target(target)
  if not delimiters[target] then
    return
  end

  local ctx = make_context()
  local pair = target_pair(pairs_in(ctx.text), cursor_offset(), target)
  if pair then
    erase_pair(ctx, pair)
  end
end

function M.delete_wrapper_at_cursor()
  local ctx = make_context()
  local offset = cursor_offset()
  local found = pairs_in(ctx.text)
  local char = ctx.text:sub(offset + 1, offset + 1)

  if delimiters[char] then
    local pair = exact_pair_at(found, offset)
    if pair then
      erase_pair(ctx, pair)
    end
    return
  end

  local wrapper = wrapper_at_cursor(ctx, found, offset)
  if wrapper then
    erase_pair(ctx, wrapper.pair, wrapper.prefix_start)
  end
end

function M.delete_current_or_next()
  local ctx = make_context()
  local offset = cursor_offset()
  local pair = innermost_pair(pairs_in(ctx.text), offset) or next_pair(pairs_in(ctx.text), offset)
  if pair then
    erase_pair(ctx, pair)
  end
end

function M.delete_parent_or_previous()
  local ctx = make_context()
  local offset = cursor_offset()
  local found = pairs_in(ctx.text)
  local parent, current = parent_pair(found, offset)
  local pair = parent or previous_pair(found, current and current.open or offset)
  if pair then
    erase_pair(ctx, pair)
  end
end

function M.setup()
  vim.keymap.set("n", "gsD", M.delete_wrapper_at_cursor, {
    desc = "Delete wrapper at cursor",
  })

  vim.keymap.set("n", "gsd", function()
    local target = vim.fn.getcharstr()

    if target == "d" then
      M.delete_current_or_next()
    elseif target == "D" then
      M.delete_parent_or_previous()
    else
      M.delete_target(target)
    end
  end, {
    desc = "Delete surrounding",
  })
end

return M
