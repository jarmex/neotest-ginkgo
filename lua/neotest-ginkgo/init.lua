local fn = vim.fn
local Path = require("plenary.path")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")
local utils = require("neotest-ginkgo.utils")
local output = require("neotest-ginkgo.output")
local test_statuses = require("neotest-ginkgo.test_status")

print("Loading neotest-ginkgo")

local get_args = function()
  return {}
end

local recursive_run = function()
  return false
end

---@type neotest.Adapter
local adapter = { name = "neotest-ginkgo" }

adapter.root = lib.files.match_root_pattern("go.mod", "go.sum")

function adapter.is_test_file(file_path)
  if not vim.endswith(file_path, ".go") then
    return false
  end
  local elems = vim.split(file_path, Path.path.sep)
  local file_name = elems[#elems]
  local is_test = vim.endswith(file_name, "_test.go")
  return is_test
end

---@param position neotest.Position The position to return an ID for
---@param namespaces neotest.Position[] Any namespaces the position is within
function adapter._generate_position_id(position, namespaces)
  local prefix = {}
  for _, namespace in ipairs(namespaces) do
    if namespace.type ~= "file" then
      table.insert(prefix, namespace.name)
    end
  end
  local name = utils.transform_test_name(position.name)
  return table.concat(vim.tbl_flatten({ position.path, prefix, name }), "::")
end

---@async
---@return neotest.Tree| nil
function adapter.discover_positions(path)
  local query = [[
    ;;query for Namespace or Context Block
    ((call_expression
      function: (identifier) @func_name (#match? @func_name "^(Describe|Context)$")
      arguments: (argument_list (_) @namespace.name (func_literal))
    )) @namespace.definition

    ;;query for It or DescribeTable block
    ((call_expression
        function: (identifier) @func_name
        arguments: (argument_list (_) @test.name (func_literal))
    ) (#match? @func_name "^(It|DescribeTable)$")) @test.definition
  ]]

  return lib.treesitter.parse_positions(path, query, {
    require_namespaces = false,
    nested_tests = true,
    position_id = "require('neotest-ginkgo')._generate_position_id",
  })
end

---@async
---@param args neotest.RunArgs
---@return neotest.RunSpec
function adapter.build_spec(args)
  local results_path = async.fn.tempname()
  local position = args.tree:data()
  local dir = "./"
  if recursive_run() then
    dir = "./..."
  end
  local location = position.path
  if fn.isdirectory(position.path) ~= 1 then
    location = fn.fnamemodify(position.path, ":h")
  end
  local command = vim.tbl_flatten({
    "cd",
    location,
    "&&",
    "ginkgo",
    "-v",
    "-json",
    utils.get_build_tags(),
    vim.list_extend(get_args(), args.extra_args or {}),
    dir,
  })
  return {
    command = table.concat(command, " "),
    context = {
      results_path = results_path,
      file = position.path,
    },
  }
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result[]>
function adapter.results(spec, result, tree)
  local go_root = utils.get_go_root(spec.context.file)
  if not go_root then
    return {}
  end
  local go_module = utils.get_go_module_name(go_root)
  if not go_module then
    return {}
  end

  local success, lines = pcall(lib.files.read_lines, result.output)
  if not success then
    logger.error("neotest-ginkgo: could not read output: " .. lines)
    return {}
  end
  return adapter.prepare_results(tree, lines, go_root, go_module)
end

---@param tree neotest.Tree
---@param lines string[]
---@param go_root string
---@param go_module string
---@return table<string, neotest.Result[]>
function adapter.prepare_results(tree, lines, go_root, go_module)
  local tests, log = output.marshal_gotest_output(lines)
  local results = {}
  local no_results = vim.tbl_isempty(tests)
  local empty_result_fname
  local file_id
  empty_result_fname = async.fn.tempname()
  fn.writefile(log, empty_result_fname)
  for _, node in tree:iter_nodes() do
    local value = node:data()
    if no_results then
      results[value.id] = {
        status = test_statuses.fail,
        output = empty_result_fname,
      }
      break
    end
    if value.type == "file" then
      results[value.id] = {
        status = test_statuses.pass,
        output = empty_result_fname,
      }
      file_id = value.id
    else
      local normalized_id = utils.normalize_id(value.id, go_root, go_module)
      local test_result = tests[normalized_id]
      -- file level node
      if test_result then
        local fname = async.fn.tempname()
        fn.writefile(test_result.output, fname)
        results[value.id] = {
          status = test_result.status,
          short = table.concat(test_result.output, ""),
          output = fname,
        }
        local errors = utils.get_errors_from_test(test_result, utils.get_filename_from_id(value.id))
        if errors then
          results[value.id].errors = errors
        end
        if test_result.status == test_statuses.fail and file_id then
          results[file_id].status = test_statuses.fail
        end
      end
    end
  end
  return results
end

local is_callable = function(obj)
  return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

setmetatable(adapter, {
  __call = function(_, opts)
    if is_callable(opts.args) then
      get_args = opts.args
    elseif opts.args then
      get_args = function()
        return opts.args
      end
    end

    if is_callable(opts.recursive_run) then
      recursive_run = opts.recursive_run
    elseif opts.recursive_run then
      recursive_run = function()
        return opts.recursive_run
      end
    end
    return adapter
  end,
})

return adapter
