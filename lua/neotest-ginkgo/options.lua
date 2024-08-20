local Options = {}

local opts = {
  command = { "ginkgo", "-v", "-failfast" },
  dap_go_enabled = true,
  dap_go_opts = {},
}

function Options.setup(user_opts)
  if type(user_opts) == "table" and not vim.tbl_isempty(user_opts) then
    for k, v in pairs(user_opts) do
      opts[k] = v
    end
  end
end

function Options.get()
  return opts
end

function Options.dap_go_enabled()
  return opts.dap_go_enabled
end

function Options.dap_go_opts()
  return opts.dap_go_opts
end

function Options.command()
  return opts.command
end

function Options.set(updated_opts)
  for k, v in pairs(updated_opts) do
    opts[k] = v
  end
  return opts
end

return Options
