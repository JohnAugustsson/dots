local paths = require("config.project_paths")
local uv = vim.uv or vim.loop

local temp_dirs = {}

local function temp_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  table.insert(temp_dirs, dir)
  return dir
end

describe("project path handling", function()
  after_each(function()
    for _, dir in ipairs(temp_dirs) do
      vim.fn.delete(dir, "rf")
    end
    temp_dirs = {}
  end)

  it("preserves the filesystem root", function()
    assert.are.same("/", paths.normalize("/"))
    assert.is_true(paths.is_inside("/tmp/example", "/"))
  end)

  it("resolves a new file through the nearest existing symlink ancestor", function()
    local base = temp_dir()
    local real = base .. "/real-project"
    local link = base .. "/linked-project"
    vim.fn.mkdir(real .. "/nested", "p")
    vim.fn.writefile({}, real .. "/.project-root")
    assert.is_true(uv.fs_symlink(real, link))

    local new_file = link .. "/nested/not-created-yet.lua"
    assert.are.same(real .. "/nested/not-created-yet.lua", paths.normalize(new_file))
    assert.are.same(
      real,
      paths.find_root(new_file, {
        require_saved_root = true,
        saved_roots = { link },
      })
    )
  end)

  it("does not recognize paths outside configured roots when required", function()
    local project = temp_dir()
    local configured = temp_dir()
    vim.fn.writefile({}, project .. "/.project-root")

    assert.is_nil(paths.find_root(project .. "/new.txt", {
      require_saved_root = true,
      saved_roots = { configured },
    }))
  end)
end)
