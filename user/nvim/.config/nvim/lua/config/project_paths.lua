local M = {}

local uv = vim.uv or vim.loop

M.markers = {
  ".project-root",
  ".git",
  ".jj",
  "package.json",
  "pyproject.toml",
  "Cargo.toml",
  "Makefile",
}

local function clean_absolute_path(path)
  local expanded = vim.fn.fnamemodify(path, ":p")
  if expanded == "" then
    return nil
  end

  expanded = expanded:gsub("/+", "/"):gsub("/+$", "")
  return expanded == "" and "/" or expanded
end

---Normalize a path and resolve symlinks even when its final component does not
---exist yet. This keeps new files below a symlinked project in the same path
---namespace as existing files in that project.
---@param path string
---@return string|nil
function M.normalize(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  local absolute = clean_absolute_path(path)
  if not absolute then
    return nil
  end

  local candidate = absolute
  local suffix = {}
  while candidate do
    local real = uv.fs_realpath(candidate)
    if real then
      real = clean_absolute_path(real)
      if #suffix == 0 then
        return real
      end
      local joined = real == "/" and ("/" .. table.concat(suffix, "/")) or (real .. "/" .. table.concat(suffix, "/"))
      return clean_absolute_path(joined)
    end

    if candidate == "/" then
      break
    end
    table.insert(suffix, 1, vim.fn.fnamemodify(candidate, ":t"))
    local parent = clean_absolute_path(vim.fn.fnamemodify(candidate, ":h"))
    if not parent or parent == candidate then
      break
    end
    candidate = parent
  end

  return absolute
end

function M.is_inside(path, root)
  path = M.normalize(path)
  root = M.normalize(root)
  if not path or not root then
    return false
  end
  if root == "/" then
    return path:sub(1, 1) == "/"
  end
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

---@param roots_file? string
---@return string[]
function M.load_saved_roots(roots_file)
  roots_file = roots_file or vim.fn.expand("~/.config/project-root-picker/project-roots")
  local roots = {}
  if vim.fn.filereadable(roots_file) == 0 then
    return roots
  end

  for _, line in ipairs(vim.fn.readfile(roots_file)) do
    local root = M.normalize(vim.trim(line))
    if root and uv.fs_stat(root) then
      table.insert(roots, root)
    end
  end

  table.sort(roots, function(a, b)
    return #a > #b
  end)
  return roots
end

---@param path string
---@param roots? string[]
---@return string|nil
function M.saved_root_for(path, roots)
  path = M.normalize(path)
  if not path then
    return nil
  end
  for _, root in ipairs(roots or M.load_saved_roots()) do
    root = M.normalize(root)
    if root and M.is_inside(path, root) then
      return root
    end
  end
  return nil
end

local function starting_directory(path)
  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return path
  end
  return M.normalize(vim.fn.fnamemodify(path, ":h"))
end

---@class ProjectRootOptions
---@field require_saved_root? boolean Only recognize projects below a configured root.
---@field saved_roots? string[] Override configured roots (primarily useful for tests).
---@field markers? string[]

---@param start_path string
---@param opts? ProjectRootOptions
---@return string|nil
function M.find_root(start_path, opts)
  opts = opts or {}
  local path = M.normalize(start_path)
  if not path then
    return nil
  end

  local saved_root = M.saved_root_for(path, opts.saved_roots)
  if opts.require_saved_root and not saved_root then
    return nil
  end

  local dir = starting_directory(path)
  while dir do
    for _, marker in ipairs(opts.markers or M.markers) do
      if uv.fs_stat(dir .. (dir == "/" and "" or "/") .. marker) then
        return dir
      end
    end

    if saved_root and dir == saved_root then
      break
    end
    if dir == "/" then
      break
    end
    local parent = M.normalize(vim.fn.fnamemodify(dir, ":h"))
    if not parent or parent == dir then
      break
    end
    dir = parent
  end

  return saved_root
end

return M
