local M = { log_file = nil }

---@param log_file string
function M.setup_notify(log_file)
  M.log_file = log_file
end

function M.log(level, msg)
  if M.log_file then
    vim.fn.writefile({ ('[%s] %s'):format(level, msg) }, M.log_file, 'a')
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

---@param msg string
function M.fatal(msg)
  local lvl = vim.log.levels.ERROR
  local full_msg = 'DevChronicles Fatal: ' .. msg
  M.notify(full_msg, lvl)
  M.log(lvl, msg)
  error(full_msg, 2)
end

return M
