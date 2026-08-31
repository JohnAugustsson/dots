local picker = require("config.project_picker")
local cleanup = require("config.buffer_cleanup")
local paths = require("config.project_paths")

local original_cwd = vim.fn.getcwd()
local original_notify = vim.notify
local original_persistence = package.loaded.persistence
local original_sessionoptions = vim.o.sessionoptions
local original_load_saved_roots = paths.load_saved_roots
local temp_dirs = {}

local function temp_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  table.insert(temp_dirs, dir)
  return dir
end

local function write_file(path)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile({ path }, path)
end

local function reset_editor()
  vim.cmd("silent! %bwipeout!")
  vim.cmd("enew")
end

local function install_persistence(destination_root, opts)
  opts = opts or {}
  local missing_session = temp_dir() .. "/missing-session.vim"
  package.loaded.persistence = {
    current = function()
      if vim.fn.getcwd() == destination_root then
        return opts.destination_session or missing_session
      end
      return temp_dir() .. "/source-session.vim"
    end,
    save = opts.save or function() end,
    load = opts.load or function() end,
  }
end

describe("project session switching", function()
  before_each(function()
    reset_editor()
    vim.notify = function() end
    picker._switching_project = false
    vim.o.sessionoptions = original_sessionoptions
  end)

  after_each(function()
    package.loaded.persistence = original_persistence
    paths.load_saved_roots = original_load_saved_roots
    vim.notify = original_notify
    picker._switching_project = false
    pcall(vim.api.nvim_del_augroup_by_name, "ja_buffer_cleanup")
    pcall(vim.api.nvim_del_augroup_by_name, "ja_project_session_switch")
    vim.api.nvim_set_current_dir(original_cwd)
    reset_editor()
    for _, dir in ipairs(temp_dirs) do
      vim.fn.delete(dir, "rf")
    end
    temp_dirs = {}
  end)

  it("excludes an already-open destination file while saving every source buffer", function()
    local source = temp_dir()
    local destination = temp_dir()
    local source_a = source .. "/a.txt"
    local source_b = source .. "/b.txt"
    local target = destination .. "/target.txt"
    local saved_session = source .. "/saved-session.vim"
    write_file(source_a)
    write_file(source_b)
    write_file(target)

    vim.api.nvim_set_current_dir(source)
    vim.cmd.edit(source_a)
    local source_a_buf = vim.api.nvim_get_current_buf()
    vim.cmd.badd(source_b)
    local source_b_buf = vim.fn.bufnr(source_b)
    vim.cmd.edit(target) -- Mirrors the state seen by the BufReadPost handler.
    local target_buf = vim.api.nvim_get_current_buf()

    local save_checked = false
    install_persistence(destination, {
      save = function()
        save_checked = true
        assert.is_true(vim.api.nvim_buf_is_valid(source_a_buf))
        assert.is_true(vim.api.nvim_buf_is_valid(source_b_buf))
        assert.is_false(vim.bo[target_buf].buflisted)
        assert.are.same(0, #vim.fn.win_findbuf(target_buf))
        vim.opt.sessionoptions:append("buffers")
        vim.cmd.mksession({ args = { saved_session }, bang = true })
      end,
    })

    assert.is_true(picker._switch_to_project_root(destination, { silent_no_session = true }))
    assert.is_true(save_checked)
    assert.are.same(destination, vim.fn.getcwd())
    assert.is_false(vim.api.nvim_buf_is_valid(source_a_buf))
    assert.is_false(vim.api.nvim_buf_is_valid(source_b_buf))
    assert.is_false(vim.api.nvim_buf_is_valid(target_buf))
    assert.are.same("", vim.api.nvim_buf_get_name(0))

    local session_contents = table.concat(vim.fn.readfile(saved_session), "\n")
    assert.is_truthy(session_contents:find(source_a, 1, true))
    assert.is_truthy(session_contents:find(source_b, 1, true))
    assert.is_nil(session_contents:find(target, 1, true))
  end)

  it("loads an existing destination session after resetting source state", function()
    local source = temp_dir()
    local destination = temp_dir()
    local source_file = source .. "/source.txt"
    local loaded_file = destination .. "/restored.txt"
    local session = destination .. "/session.vim"
    write_file(source_file)
    write_file(loaded_file)
    vim.fn.writefile({}, session)
    vim.api.nvim_set_current_dir(source)
    vim.cmd.edit(source_file)
    local source_buf = vim.api.nvim_get_current_buf()

    local loaded = false
    install_persistence(destination, {
      destination_session = session,
      load = function()
        loaded = true
        vim.cmd.edit(loaded_file)
      end,
    })

    assert.is_true(picker._switch_to_project_root(destination, { silent_no_session = true }))
    assert.is_true(loaded)
    assert.is_false(vim.api.nvim_buf_is_valid(source_buf))
    assert.are.same(loaded_file, vim.api.nvim_buf_get_name(0))
  end)

  it("refuses to destroy a modified unlisted buffer", function()
    local source = temp_dir()
    local destination = temp_dir()
    local modified_file = source .. "/modified.txt"
    write_file(modified_file)
    vim.api.nvim_set_current_dir(source)
    local modified_buf = vim.fn.bufadd(modified_file)
    vim.fn.bufload(modified_buf)
    vim.bo[modified_buf].buflisted = false
    vim.api.nvim_buf_set_lines(modified_buf, 0, -1, false, { "unsaved" })

    local saved = false
    install_persistence(destination, {
      save = function()
        saved = true
      end,
    })

    assert.is_false(picker._switch_to_project_root(destination, { silent_no_session = true }))
    assert.is_false(saved)
    assert.is_true(vim.api.nvim_buf_is_valid(modified_buf))
    assert.is_true(vim.bo[modified_buf].modified)
    assert.are.same(source, vim.fn.getcwd())
  end)

  it("refuses to kill a running terminal", function()
    local source = temp_dir()
    local destination = temp_dir()
    vim.api.nvim_set_current_dir(source)
    local terminal_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(terminal_buf)
    assert.is_true(vim.fn.termopen({ "sleep", "10" }) > 0)

    local saved = false
    install_persistence(destination, {
      save = function()
        saved = true
      end,
    })

    assert.is_false(picker._switch_to_project_root(destination, { silent_no_session = true }))
    assert.is_false(saved)
    assert.is_true(vim.api.nvim_buf_is_valid(terminal_buf))
    assert.are.same(source, vim.fn.getcwd())
  end)

  it("clears the switching guard and restores the destination window after save errors", function()
    local source = temp_dir()
    local destination = temp_dir()
    local source_file = source .. "/source.txt"
    local target = destination .. "/target.txt"
    write_file(source_file)
    write_file(target)
    vim.api.nvim_set_current_dir(source)
    vim.cmd.edit(source_file)
    vim.cmd.edit(target)
    local target_buf = vim.api.nvim_get_current_buf()

    install_persistence(destination, {
      save = function()
        error("intentional save failure")
      end,
    })

    assert.is_false(picker._switch_to_project_root(destination, { silent_no_session = true }))
    assert.is_false(picker._switching_project)
    assert.are.same(source, vim.fn.getcwd())
    assert.are.same(target_buf, vim.api.nvim_get_current_buf())
    assert.is_true(vim.bo[target_buf].buflisted)
  end)

  it("preserves the source through the real BufLeave and BufReadPost scheduling order", function()
    local source = temp_dir()
    local destination = temp_dir()
    local source_file = source .. "/source.txt"
    local target = destination .. "/target.txt"
    local saved_session = source .. "/autocmd-session.vim"
    vim.fn.writefile({}, source .. "/.project-root")
    vim.fn.writefile({}, destination .. "/.project-root")
    write_file(source_file)
    write_file(target)

    paths.load_saved_roots = function()
      return { source, destination }
    end
    local saved_source = false
    install_persistence(destination, {
      save = function()
        local source_buf = vim.fn.bufnr(source_file)
        saved_source = source_buf > 0 and vim.api.nvim_buf_is_valid(source_buf)
        vim.opt.sessionoptions:append("buffers")
        vim.cmd.mksession({ args = { saved_session }, bang = true })
      end,
    })
    cleanup.setup()
    picker.setup()

    vim.api.nvim_set_current_dir(source)
    vim.cmd.edit(source_file)
    vim.cmd.edit(target)

    assert.is_true(vim.wait(2000, function()
      return vim.fn.getcwd() == destination and vim.api.nvim_buf_get_name(0) == target
    end))
    assert.is_true(saved_source)
    local session_contents = table.concat(vim.fn.readfile(saved_session), "\n")
    assert.is_truthy(session_contents:find(source_file, 1, true))
    assert.is_nil(session_contents:find(target, 1, true))
  end)
end)
