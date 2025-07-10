local M = {}

local defaults = {
  tracked_parent_dirs = {},
  tracked_dirs = {},
  exclude_subdirs_relative = {},
  exclude_dirs_absolute = {},
  min_session_time = 180,
  data_file = 'dev-chronicles.json',
  log_file = 'log.dev-chronicles.log',
  dashboard = {
    header = {
      color_proj_times_like_bars = false,
      total_time_as_hours_max = true,
    },
    bar_width = 10,
    bar_spacing = 3,
    bar_chars = {
      { '/', '\\' },
      { '|' },
      { '┼' },
      { '╳' },
      { '@' },
    },
    sort = true,
    sort_by_last_worked_not_total_time = true,
    ascending = true,
    n_months_by_default = 2,
    proj_total_time_as_hours_max = true,
    footer = {
      let_proj_names_extend_bars_by_one = false,
    },
    dashboard_all = {
      sort = true,
      sort_by_last_worked_not_total_time = false,
      ascending = true,
    },
  },
}

---@class chronicles.Options.Dashboard.All
---@field sort boolean Whether to sort the projects when displaying all chronicles data
---@field sort_by_last_worked_not_total_time boolean Whether to sort using last worked time instead of total worked time when displaying all chronicles data
---@field ascending boolean Whether to sort in ascending order when displaying all chronicles data

---@class chronicles.Options.Dashboard.Header
---@field color_proj_times_like_bars boolean Whether to color project time stats the same as their bars
---@field total_time_as_hours_max boolean Format total time as at most hours

---@class chronicles.Options.Dashboard.Footer
---@field let_proj_names_extend_bars_by_one boolean

---@class chronicles.Options.Dashboard
---@field header chronicles.Options.Dashboard.Header
---@field bar_width integer width of each column
---@field bar_spacing integer spacing between each column
---@field bar_chars string[][] All the bar representation patterns
---@field sort boolean Whether to sort the projects
---@field sort_by_last_worked_not_total_time boolean Whether to sort using last worked time instead of total worked time
---@field ascending boolean Whether to sort in ascending order
---@field n_months_by_default integer Number of months for default dashboard
---@field proj_total_time_as_hours_max boolean Format total time for each project as at most hours
---@field footer chronicles.Options.Dashboard.Footer
---@field dashboard_all chronicles.Options.Dashboard.All

---@class chronicles.Options
---@field tracked_parent_dirs string[] List of dirs to track
---@field tracked_dirs string[] List of paths to track
---@field exclude_subdirs_relative table<string, boolean> List of subdirs to exclude from tracked_parent_dirs subdirs
---@field exclude_dirs_absolute string[] List of absolute dirs to exclude (tracked_parent_dirs can have two different dirs that have two subdirs of the same name)
---@field min_session_time integer Minimum session time in seconds
---@field dashboard chronicles.Options.Dashboard
---@field data_file string Path to the data file
---@field log_file string Path to the log file
M.options = {}

M.setup = function(opts)
  local utils = require('dev-chronicles.utils')

  ---@type chronicles.Options
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
