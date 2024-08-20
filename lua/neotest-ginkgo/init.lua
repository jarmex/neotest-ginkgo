local query = require("neotest-ginkgo.query")
local logger = require("neotest.logging")
local utils = require("neotest-ginkgo.utils")
local runtest = require("neotest-ginkgo.runtest")
local results = require("neotest-ginkgo.results")
local options = require("neotest-ginkgo.options")

local M = {}

--- See neotest.Adapter for the full interface.
--- @class Adapter : neotest.Adapter
--- @field name string
M.Adapter = {
  name = "neotest-ginkgo",
}

--- Find the project root directory given a current directory to work from.
--- Should no root be found, the adapter can still be used in a non-project context if a test file matches.
--- @async
--- @param dir string @Directory to treat as cwd
--- @return string | nil @Absolute root dir of test suite
function M.Adapter.root(dir)
  -- return lib.files.match_root_pattern("go.mod", "go.sum")
  return dir
end

--- @async
--- @param file_path string
--- @return boolean
function M.Adapter.is_test_file(file_path)
  if file_path == nil then
    return false
  end
  return vim.endswith(file_path, "_test.go")
end

---@param position neotest.Position The position to return an ID for
---@param namespaces neotest.Position[] Any namespaces the position is within
---@return string
function M.Adapter._generate_position_id(position, namespaces)
  local prefix = {}
  for _, namespace in ipairs(namespaces) do
    if namespace.type ~= "file" then
      table.insert(prefix, namespace.name)
    end
  end
  -- local name = utils.transform_test_name(position.name)
  return table.concat(utils.tbl_flatten({ position.path, prefix, position.name }), "::")
end

---Given a file path, parse all the tests within it.
---@async
---@param path string Absolute file path
---@return neotest.Tree| nil
function M.Adapter.discover_positions(path)
  return query.test_names(path)
end

--- Build the runspec, which describes what command(s) are to be executed.
--- @async
--- @param args neotest.RunArgs
--- @return nil | neotest.RunSpec | neotest.RunSpec[]
function M.Adapter.build_spec(args)
  --- The tree object, describing the AST-detected tests and their positions.
  --- @type neotest.Tree
  local tree = args.tree

  --- The position object, describing the current directory, file or test.
  --- @type neotest.Position
  local position = args.tree:data()

  if not tree then
    vim.notify("Unexpectedly did not receive a neotest.Tree.", vim.log.levels.ERROR)
    return
  end
  if position.type == "dir" and position.path == vim.fn.getcwd() then
    return runtest.dir.build(position)
  elseif position.type == "dir" then
    return runtest.dir.build(position)
  elseif position.type == "file" then
    return runtest.file.build(position, tree)
  elseif position.type == "namespace" then
    return runtest.namespace.build(position)
  elseif position.type == "test" then
    return runtest.test.build(position, args.strategy)
  end
  logger.error("Unknown Neotest position type, " .. "cannot build runspec with position type: " .. position.type)
end

--- Process the test command output and result. Populate test outcome into the
--- Neotest internal tree structure.
--- @async
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result> | nil
function M.Adapter.results(spec, result, tree)
  if spec.context.pos_type == "dir" then
    return results.test_results(spec, result, tree)
  elseif spec.context.pos_type == "file" then
    return results.test_results(spec, result, tree)
  elseif spec.context.pos_type == "namespace" then
    return results.test_results(spec, result, tree)
  elseif spec.context.pos_type == "test" then
    return results.test_results(spec, result, tree)
  end

  logger.error("Cannot process test results due to unknown Neotest position type:" .. spec.context.pos_type)
end

--- Adapter options.
setmetatable(M.Adapter, {
  __call = function(_, opts)
    M.Adapter.options = options.setup(opts)
    return M.Adapter
  end,
})

return M.Adapter
