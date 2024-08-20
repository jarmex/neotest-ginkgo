--- Build the neotest.Runspec specification for a test execution.

local M = {}

M.dir = require("neotest-ginkgo.runtest.dir")
M.file = require("neotest-ginkgo.runtest.file")
M.namespace = require("neotest-ginkgo.runtest.namespace")
M.test = require("neotest-ginkgo.runtest.test")

return M
