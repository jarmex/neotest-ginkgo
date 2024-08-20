local fn = vim.fn
local async = require("neotest.async")
local test_statuses = require("neotest-ginkgo.test_status")

local M = {}

--- @param lines string[]
--- @return string
local isTestAllFailed = function(lines)
  --- @type string
  local lastLine = lines[#lines]

  if lastLine ~= nil and lastLine:find("Test Suite Passed") then
    return test_statuses.pass
  end

  if lastLine ~= nil and lastLine:find("Test Suite Failed") then
    return test_statuses.fail
  end

  local pattern = "(%u+)!.+%d+%s*Passed.+%d+%s*Failed.+%d+%s*Pending.+%d+%s*Skipped"

  for _, text in ipairs(lines) do
    for line in text:gmatch("[^\r\n]+") do
      local status = line:match(pattern)
      if status and status == "FAIL" then
        -- print("Status: " .. status)
        return test_statuses.fail
      end
    end
  end

  return test_statuses.pass
end

--- @param lines string[]
--- @param testname string
--- @return string
local isTestFailed = function(lines, testname)
  local lastLine = lines[#lines]

  if lastLine ~= nil and lastLine:find("Test Suite Passed") then
    return test_statuses.pass
  end

  if lastLine ~= nil and lastLine:find("Test Suite Failed") then
    return test_statuses.fail
  end

  testname = string.gsub(testname, '"', "")
  local pattern = "%[%w+.*%].+%[It%]%s" .. testname

  for _, text in ipairs(lines) do
    for line in text:gmatch("[^\r\n]+") do
      if line:find(pattern) then
        return test_statuses.fail
      end
    end
  end

  return test_statuses.pass
end

--- Process the results from the test command executing all tests in a
--- directory.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.test_results(spec, result, tree)
  --- @type table<string, neotest.Result>
  local results = {}

  local empty_result_fname = vim.fs.normalize(async.fn.tempname())
  fn.writefile(result, empty_result_fname)

  for _, node in tree:iter_nodes() do
    local value = node:data()

    if value.type == "file" then
      results[value.id] = {
        status = isTestAllFailed(result),
        output = empty_result_fname,
      }
    elseif value.type == "test" then
      results[value.id] = {
        status = isTestAllFailed(result),
        output = empty_result_fname,
      }
    else
      results[value.id] = {
        status = isTestFailed(result, value.name),
        output = empty_result_fname,
      }
    end
  end

  return results
end

return M
