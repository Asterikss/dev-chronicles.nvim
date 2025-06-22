local M = {}

M.setup = function(opts)
  require('dev-chronicles.config').setup(opts)
end

return setmetatable(M, {
  __index = function(_, k)
    return require('dev-chronicles.api')[k]
  end,
})
