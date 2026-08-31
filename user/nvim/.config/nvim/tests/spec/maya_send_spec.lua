local bootstrap = require("maya-send.bootstrap")
local config = require("maya-send.config")
local dedent = require("maya-send.dedent")
local maya = require("maya-send")

local uv = vim.uv or vim.loop

local function start_server(received)
  local server = uv.new_tcp()
  server:bind("127.0.0.1", 0)
  server:listen(1, function(err)
    assert(not err, err)
    local client = uv.new_tcp()
    server:accept(client)
    client:read_start(function(read_err, chunk)
      if chunk then
        table.insert(received, chunk)
      else
        client:close()
      end
    end)
  end)

  return server, server:getsockname().port
end

local function temp_files()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir, {
    code = dir .. "/code.py",
    bootstrap = dir .. "/boot.py",
    output = dir .. "/output.log",
  }
end

describe("maya-send dedent", function()
  it("strips the common indentation of a block", function()
    local lines = dedent.dedent({ "    if x:", "", "        pass" }, 4)
    assert.are.same({ "if x:", "", "    pass" }, lines)
  end)

  it("expands tabs to the configured tabstop", function()
    local lines = dedent.dedent({ "\tif x:", "\t\tpass" }, 4)
    assert.are.same({ "if x:", "    pass" }, lines)
  end)

  it("leaves unindented blocks alone", function()
    local lines = { "if x:", "    pass" }
    assert.are.same(lines, dedent.dedent(lines, 4))
  end)
end)

describe("maya-send bootstrap", function()
  it("appends a run call with quoted paths", function()
    local source = assert(bootstrap.render("/tmp/code.py", "/tmp/out.log"))
    assert.is_truthy(source:find("def _nvim_maya_run(", 1, true))
    assert.is_truthy(source:find('_nvim_maya_run("/tmp/code.py", "/tmp/out.log")', 1, true))
  end)

  it("escapes quotes in paths", function()
    local source = assert(bootstrap.render('/tmp/o"dd.py', "/tmp/out.log"))
    assert.is_truthy(source:find('_nvim_maya_run("/tmp/o\\"dd.py", "/tmp/out.log")', 1, true))
  end)
end)

describe("maya-send", function()
  local notifications
  local original_notify

  before_each(function()
    notifications = {}
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
  end)

  after_each(function()
    vim.notify = original_notify
    config.set({})
  end)

  it("refuses to send blank code", function()
    maya.send_lines({ "", "   " })
    assert.are.same(1, #notifications)
    assert.are.same(vim.log.levels.WARN, notifications[1].level)
  end)

  it("writes the code and asks the commandPort to exec the bootstrap", function()
    local received = {}
    local server, port = start_server(received)
    local dir, files = temp_files()

    config.set({ port = port, files = files })
    maya.send_lines({ "import maya.cmds as cmds", "cmds.ls()" })

    assert.is_true(vim.wait(2000, function()
      return #received > 0
    end, 10))

    local command = table.concat(received)
    assert.are.same(string.format('python("exec(open(\\"%s\\").read())");\n', files.bootstrap), command)
    assert.are.same({ "import maya.cmds as cmds", "cmds.ls()" }, vim.fn.readfile(files.code))
    assert.is_truthy(table.concat(vim.fn.readfile(files.bootstrap), "\n"):find("_nvim_maya_run(", 1, true))

    server:close()
    vim.fn.delete(dir, "rf")
  end)

  it("reports a closed commandPort", function()
    local server, port = start_server({})
    server:close()

    local dir, files = temp_files()
    config.set({ port = port, files = files })
    maya.send_lines({ "cmds.ls()" })

    assert.is_true(vim.wait(2000, function()
      return #notifications > 1
    end, 10))

    local last = notifications[#notifications]
    assert.are.same(vim.log.levels.ERROR, last.level)
    assert.is_truthy(last.msg:find("commandPort", 1, true))

    vim.fn.delete(dir, "rf")
  end)

  it("registers the command and mappings", function()
    maya.setup({ keys = { send = "<M-E>" } })

    assert.is_truthy(vim.api.nvim_get_commands({})["MayaSend"])
    assert.is_truthy(vim.fn.maparg("<M-E>", "n"))
    assert.is_truthy(vim.fn.maparg("<M-E>", "x"))
  end)
end)
