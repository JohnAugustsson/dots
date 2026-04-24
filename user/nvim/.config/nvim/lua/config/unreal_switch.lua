local M = {}

local uv = vim.uv or vim.loop

local function exists(path)
  return path and uv.fs_stat(path) ~= nil
end

local function normalize(path)
  return vim.fs.normalize(path)
end

local function dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

local function basename(path)
  return vim.fn.fnamemodify(path, ":t:r")
end

local function ext(path)
  return vim.fn.fnamemodify(path, ":e")
end

local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function add_unique(results, seen, path)
  path = normalize(path)
  if not seen[path] then
    seen[path] = true
    table.insert(results, path)
  end
end

local function paired_extensions(current_ext)
  current_ext = current_ext:lower()
  if current_ext == "h" or current_ext == "hpp" or current_ext == "hh" then
    return { "cpp", "cc", "cxx", "c" }
  end
  return { "h", "hpp", "hh" }
end

local function swap_segment(dir, from, to)
  local parts = vim.split(normalize(dir), "/", { plain = true, trimempty = true })
  local changed = false

  for i, part in ipairs(parts) do
    if part == from then
      parts[i] = to
      changed = true
    end
  end

  if not changed then
    return nil
  end

  return "/" .. table.concat(parts, "/")
end

local function transformed_dirs(dir)
  local dirs, seen = { normalize(dir) }, { [normalize(dir)] = true }
  local swaps = {
    { "Public", "Private" },
    { "Private", "Public" },
    { "Classes", "Private" },
    { "Classes", "Public" },
    { "Private", "Classes" },
    { "Public", "Classes" },
  }

  for _, pair in ipairs(swaps) do
    local swapped = swap_segment(dir, pair[1], pair[2])
    if swapped and not seen[swapped] then
      seen[swapped] = true
      table.insert(dirs, swapped)
    end
  end

  return dirs
end

local function candidate_paths(path)
  local dir = dirname(path)
  local name = basename(path)
  local exts = paired_extensions(ext(path))
  local results, seen = {}, {}

  for _, candidate_dir in ipairs(transformed_dirs(dir)) do
    for _, candidate_ext in ipairs(exts) do
      add_unique(results, seen, string.format("%s/%s.%s", candidate_dir, name, candidate_ext))
    end
  end

  return results
end

local function lsp_switch_available(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })
  return #clients > 0 and vim.fn.exists(":LspClangdSwitchSourceHeader") == 2
end

function M.switch()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)

  if path == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  for _, candidate in ipairs(candidate_paths(path)) do
    if exists(candidate) and normalize(candidate) ~= normalize(path) then
      open(candidate)
      return
    end
  end

  if lsp_switch_available(bufnr) then
    local ok = pcall(vim.cmd, "LspClangdSwitchSourceHeader")
    if ok then
      return
    end
  end

  vim.notify("No matching header/source file found", vim.log.levels.WARN)
end

return M
