local lib = require("neotest.lib")

local Query = {}

--- Detect test names in Go *._test.go files.
--- @param file_path string
--- @return neotest.Tree
function Query.test_names(file_path)
  local query = [[
    ;;query for Namespace or Context Block
    ((call_expression
      function: (identifier) @func_name (#match? @func_name "^(Describe|Context|When)$")
      arguments: (argument_list (interpreted_string_literal) @namespace.name (func_literal))
    )) @namespace.definition

    ;;query for It or DescribeTable block
    ((call_expression
        function: (identifier) @func_name
        arguments: (argument_list (interpreted_string_literal) @test.name (func_literal))
    ) (#match? @func_name "^(It|DescribeTable)$")) @test.definition


  ]]

  local opts = { nested_tests = true, position_id = "require('neotest-ginkgo')._generate_position_id" }

  ---@type neotest.Tree
  local position = lib.treesitter.parse_positions(file_path, query, opts)

  return position
end

return Query
