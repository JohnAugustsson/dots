local cleanup = require("config.buffer_cleanup")

local function make_project_files(names)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local paths = {}
  for _, name in ipairs(names) do
    local path = dir .. "/" .. name
    vim.fn.writefile({ name }, path)
    table.insert(paths, path)
  end
  return dir, paths
end

local function open_sequence(paths)
  local bufs = {}
  for _, path in ipairs(paths) do
    vim.cmd.edit(vim.fn.fnameescape(path))
    table.insert(bufs, vim.api.nvim_get_current_buf())
  end
  return bufs
end

local function reset_editor_state()
  package.loaded.harpoon = nil
  cleanup.state.recent = {}
  vim.cmd("silent! %bwipeout!")
  vim.cmd("enew")
end

describe("buffer cleanup policy", function()
  before_each(function()
    reset_editor_state()
    cleanup.setup({ debug = false, keep_recent = 8 })
  end)

  after_each(function()
    reset_editor_state()
  end)

  it("deletes the leaving buffer even when it is the alternate buffer", function()
    local dir, paths = make_project_files({ "a.txt", "b.txt", "c.txt", "d.txt" })
    local bufs = open_sequence(paths)

    cleanup.state.recent = { bufs[3], bufs[2], bufs[1] }
    cleanup.cleanup_once(bufs[3])

    assert.is_false(vim.bo[bufs[3]].buflisted)
    assert.is_true(vim.api.nvim_buf_is_valid(bufs[2]))
    assert.is_true(vim.api.nvim_buf_is_valid(bufs[4]))
    assert.are.same(bufs[4], vim.api.nvim_get_current_buf())

    vim.fn.delete(dir, "rf")
  end)

  it("never deletes modified buffers", function()
    local dir, paths = make_project_files({ "a.txt", "b.txt", "c.txt", "d.txt" })
    local bufs = open_sequence(paths)

    vim.api.nvim_set_current_buf(bufs[1])
    vim.api.nvim_buf_set_lines(bufs[1], 0, -1, false, { "changed" })
    vim.api.nvim_set_current_buf(bufs[4])

    cleanup.state.recent = { bufs[3], bufs[2], bufs[1] }
    cleanup.cleanup_once(bufs[1])

    assert.is_true(vim.api.nvim_buf_is_valid(bufs[1]))
    assert.is_true(vim.bo[bufs[1]].modified)

    vim.fn.delete(dir, "rf")
  end)

  it("never deletes harpoon files", function()
    local dir, paths = make_project_files({ "a.txt", "b.txt", "c.txt", "d.txt" })
    local bufs = open_sequence(paths)

    package.loaded.harpoon = {
      list = function()
        return { items = { { value = paths[1] } } }
      end,
    }

    cleanup.state.recent = { bufs[3], bufs[2], bufs[1] }
    cleanup.cleanup_once(bufs[1])

    assert.is_true(vim.api.nvim_buf_is_valid(bufs[1]))

    vim.fn.delete(dir, "rf")
  end)

  it("tracks one extra grace buffer beyond alternate", function()
    local dir, paths = make_project_files({ "a.txt", "b.txt", "c.txt", "d.txt" })
    local bufs = open_sequence(paths)

    cleanup.state.recent = {}
    cleanup._push_recent(bufs[1])
    cleanup._push_recent(bufs[2])
    cleanup._push_recent(bufs[3])

    local grace = cleanup._get_grace_buf(vim.api.nvim_get_current_buf(), cleanup._get_alternate_buf())
    assert.are.same(bufs[2], grace)

    vim.fn.delete(dir, "rf")
  end)

  it("still protects the alternate buffer when it is not the leaving buffer", function()
    local dir, paths = make_project_files({ "a.txt", "b.txt", "c.txt", "d.txt" })
    local bufs = open_sequence(paths)

    cleanup.state.recent = { bufs[3], bufs[2], bufs[1] }
    cleanup.cleanup_once(bufs[1])

    assert.is_true(vim.api.nvim_buf_is_valid(bufs[3]))
    assert.is_false(vim.bo[bufs[1]].buflisted)

    vim.fn.delete(dir, "rf")
  end)

  it("does not sweep unrelated recent buffers when another buffer is cleaned", function()
    local dir, paths = make_project_files({ "a.txt", "b.txt", "c.txt", "d.txt", "e.txt" })
    local bufs = open_sequence(paths)

    vim.api.nvim_set_current_buf(bufs[5])
    cleanup.state.recent = { bufs[4], bufs[3], bufs[2], bufs[1] }

    cleanup.cleanup_once(bufs[1])

    assert.is_false(vim.bo[bufs[1]].buflisted)
    assert.is_true(vim.api.nvim_buf_is_valid(bufs[2]))
    assert.is_true(vim.api.nvim_buf_is_valid(bufs[3]))
    assert.is_true(vim.api.nvim_buf_is_valid(bufs[4]))
    assert.is_true(vim.api.nvim_buf_is_valid(bufs[5]))

    vim.fn.delete(dir, "rf")
  end)
end)
