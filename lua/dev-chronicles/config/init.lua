local M = {}

local defaults = {
  tracked_dirs = {},
  tracked_paths = {},
  min_session_time = 180,
  data_file = 'dev-chronicles.json',
  log_file = 'log.dev-chronicles.log',
  dashboard = {
    sort = true,
    sort_by_last_worked_not_total_time = true,
    ascending = true,
    n_months_by_default = 2,
    proj_total_time_as_hours_max = true,
    total_time_as_hours_max = true,
  },
}

---@class DashboardOptions
---@field sort boolean Whether to sort the projects
---@field sort_by_last_worked_not_total_time boolean Whether to sort using last worked time instead of total worked time
---@field ascending boolean Whether to sort in ascending order
---@field n_months_by_default integer Number of months for default dashboard
---@field proj_total_time_as_hours_max boolean Format total time for each project as at most hours
---@field total_time_as_hours_max boolean Format total time as at most hours

---@class DevChroniclesOptions
---@field tracked_dirs string[] List of dirs to track
---@field tracked_paths string[] List of paths to track
---@field min_session_time integer Minimum session time in seconds
---@field dashboard DashboardOptions
---@field data_file string Path to the data file
---@field log_file string Path to the log file
M.options = {}

M.setup = function(opts)
  local utils = require('dev-chronicles.utils')

  ---@type DevChroniclesOptions
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})

  if type(merged.tracked_dirs) == 'string' then
    ---@diagnostic disable-next-line: assign-type-mismatch
    merged.tracked_dirs = { merged.tracked_dirs }
  end

  for i = 1, #merged.tracked_dirs do
    merged.tracked_dirs[i] = utils.expand(merged.tracked_dirs[i])
  end

  if type(merged.tracked_paths) == 'string' then
    ---@diagnostic disable-next-line: assign-type-mismatch
    merged.tracked_paths = { merged.tracked_paths }
  end

  for i = 1, #merged.tracked_paths do
    merged.tracked_paths[i] = utils.expand(merged.tracked_paths[i])
  end

  if vim.fn.isabsolutepath(merged.data_file) ~= 1 then
    merged.data_file = vim.fn.stdpath('data') .. '/' .. merged.data_file
  end

  if vim.fn.isabsolutepath(merged.log_file) ~= 1 then
    merged.log_file = vim.fn.stdpath('data') .. '/' .. merged.log_file
  else
  end

  if merged.dashboard.n_months_by_default < 1 then
    vim.notify('DevChronicles: n_months_by_default should be greter than 0')
    return
  end

  M.options = merged

  require('dev-chronicles.core').init()
end

return M
