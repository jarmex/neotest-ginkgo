local M = {}

local function split(str, sep)
  local array = {}
  local reg = string.format("([^%s]+)", sep)
  for mem in string.gmatch(str, reg) do
    table.insert(array, mem)
  end
  return array
end

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy)
  local splitvalues = split(position.id, "::")
  for key, value in ipairs(splitvalues) do
    splitvalues[key] = string.gsub(value, '"', "")
  end

  local testToRun = table.concat(splitvalues, ".*", 2, #splitvalues)

  -- print(vim.inspect(testToRun))

  vim.list_extend(command, { "--focus", '"' .. testToRun .. '"' })
end

return M
---------------------------------imported -----------------------
--- Helpers to build the command and context around running a single test.

local convert = require("neotest-golang.convert")
local options = require("neotest-golang.options")
local cmd = require("neotest-golang.cmd")
local dap = require("neotest-golang.dap")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy)
  --- @type string
  local test_folder_absolute_path = string.match(pos.path, "(.+)/")
  local golist_data = cmd.golist_data(test_folder_absolute_path)

  --- @type string
  local test_name = convert.to_gotest_test_name(pos.id)
  test_name = convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath =
    cmd.test_command_for_individual_test(test_folder_absolute_path, test_name)

  local runspec_strategy = nil
  if strategy == "dap" then
    if options.get().dap_go_enabled then
      runspec_strategy = dap.get_dap_config(test_name)
      dap.setup_debugging(test_folder_absolute_path)
    end
  end

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    pos_type = "test",
    golist_data = golist_data,
    parse_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = test_folder_absolute_path,
    context = context,
  }

  if runspec_strategy ~= nil then
    run_spec.strategy = runspec_strategy
    run_spec.context.parse_test_results = false
  end

  return run_spec
end

return M