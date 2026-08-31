local cleanup = require("config.buffer_cleanup")

local original_cwd = vim.fn.getcwd()
local temp_dirs = {}

local function temp_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  table.insert(temp_dirs, dir)
  return dir
end

local function file_buffer(path)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile({ path }, path)
  local bufnr = vim.fn.bufadd(path)
  vim.fn.bufload(bufnr)
  vim.bo[bufnr].buflisted = true
  return bufnr
end

local function reset_editor()
  vim.cmd("silent! %bwipeout!")
  vim.cmd("enew")
end

describe("buffer cleanup policy", function()
  before_each(function()
    reset_editor()
    cleanup.opts.enabled = true
    cleanup.opts.debug = false
  end)

  after_each(function()
    vim.api.nvim_set_current_dir(original_cwd)
    reset_editor()
    for _, dir in ipairs(temp_dirs) do
      vim.fn.delete(dir, "rf")
    end
    temp_dirs = {}
  end)

  it("deletes an unmodified hidden file outside the active scope", function()
    local root = temp_dir()
    vim.fn.writefile({}, root .. "/.project-root")
    local inside = file_buffer(root .. "/inside.txt")
    local outside = file_buffer(temp_dir() .. "/outside.txt")

    vim.api.nvim_set_current_dir(root)
    vim.api.nvim_set_current_buf(inside)
    cleanup.cleanup_once(outside)

    assert.is_false(vim.bo[outside].buflisted)
    assert.is_true(vim.api.nvim_buf_is_valid(inside))
  end)

  it("keeps files inside the active scope", function()
    local root = temp_dir()
    local bufnr = file_buffer(root .. "/nested/inside.txt")

    local should_delete, reason = cleanup._should_delete_buffer(bufnr, root)

    assert.is_false(should_delete)
    assert.are.same("inside-scope", reason)
  end)

  it("uses cwd scope while a destination file is waiting to switch projects", function()
    local source = temp_dir()
    local destination = temp_dir()
    vim.fn.writefile({}, source .. "/.project-root")
    vim.fn.writefile({}, destination .. "/.project-root")
    local source_buf = file_buffer(source .. "/source.txt")
    local destination_buf = file_buffer(destination .. "/destination.txt")

    vim.api.nvim_set_current_dir(source)
    vim.api.nvim_set_current_buf(source_buf)
    vim.api.nvim_set_current_buf(destination_buf)
    cleanup.cleanup_once(source_buf)

    assert.is_true(vim.api.nvim_buf_is_valid(source_buf))
    assert.is_true(vim.bo[source_buf].buflisted)
  end)

  it("keeps modified hidden files outside the active scope", function()
    local root = temp_dir()
    local bufnr = file_buffer(temp_dir() .. "/modified.txt")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "changed" })

    local should_delete, reason = cleanup._should_delete_buffer(bufnr, root)

    assert.is_false(should_delete)
    assert.are.same("modified", reason)
    assert.is_true(vim.bo[bufnr].modified)
  end)

  it("ignores unnamed and special buffers", function()
    local root = temp_dir()
    local unnamed = vim.api.nvim_create_buf(true, false)
    local special = vim.api.nvim_create_buf(true, true)

    assert.is_false(cleanup._should_delete_buffer(unnamed, root))
    assert.is_false(cleanup._should_delete_buffer(special, root))
  end)
end)
