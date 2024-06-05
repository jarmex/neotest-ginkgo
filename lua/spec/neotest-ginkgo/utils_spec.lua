local assert = require("luassert")
local utils = require("neotest-ginkgo.utils")

describe("normalize_id", function()
  it("normalize_id is correct", function()
    local tests_folder = vim.loop.cwd() .. "/neotest_ginkgo"
    local test_file = tests_folder .. "/cases_test.go"

    assert.equals("neotest_ginkgo", utils.normalize_id(test_file, tests_folder, "neotest_ginkgo"))
  end)
end)
