local M = {}

local log_path = require('dev-chronicles.config').get_opts().log_file

function M.log(level, msg)
  local f = io.open(log_path, 'a')
  if f then
    f:write(string.format('[%s] %s\n', level, msg))
    f:close()
  end
end

---@param msg string
---@param level? integer
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

---@param msg string
function M.warn(msg)
  local level = vim.log.levels.WARN
  M.notify('DevChronicles Warning: ' .. msg, level)
  M.log(level, msg)
end

---@param msg string
function M.error(msg)
  local level = vim.log.levels.ERROR
  M.notify('DevChronicles Error: ' .. msg, level)
  M.log(level, msg)
end

return M
