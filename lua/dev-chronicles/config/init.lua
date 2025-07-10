local M = {}

local defaults = {
  tracked_parent_dirs = {},
  tracked_dirs = {},
  exclude_subdirs_relative = {},
  exclude_dirs_absolute = {},
  sort_tracked_parent_dirs = false,
  min_session_time = 180,
  data_file = 'dev-chronicles.json',
  log_file = 'log.dev-chronicles.log',
  dashboard = {
    header = {
      color_proj_times_like_bars = false,
      total_time_as_hours_max = true,
      show_current_session_time = true,
      show_global_time_for_each_project = true,
      show_global_time_only_if_different = true,
      color_global_proj_times_like_bars = false,
      show_global_total_time = false,
      total_time_format_str = 'Ξ Total Time: %s',
      global_total_time_format_str = 'Σ Global Time: %s',
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
    dynamic_bar_height_months = false,
    dynamic_bar_height_months_thresholds = { 15, 25, 40 },
    dynamic_bar_height_day = false,
    dynamic_bar_height_day_thresholds = { 2, 3.5, 5 },
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
---@field show_current_session_time boolean Should the current session time be shown next to total time
---@field show_global_time_for_each_project boolean Should the global total project time be shown for each project
---@field show_global_time_only_if_different boolean
---@field color_global_proj_times_like_bars boolean

---@class chronicles.Options.Dashboard.Footer
---@field let_proj_names_extend_bars_by_one boolean

---@class chronicles.Options.Dashboard
---@field header chronicles.Options.Dashboard.Header
---@field bar_width integer width of each column
---@field bar_spacing integer spacing between each column
---@field bar_chars string[][] All the bar representation patterns
---@field sort boolean Whether to sort the projects
---@field dynamic_bar_height_months boolean
---@field dynamic_bar_height_months_thresholds integer[]
---@field dynamic_bar_height_day boolean
---@field dynamic_bar_height_day_thresholds integer[]
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
---@field sort_tracked_parent_dirs boolean If paths are not supplied from longest to shortest, then they need to be sorted like that
---@field min_session_time integer Minimum session time in seconds
---@field dashboard chronicles.Options.Dashboard
---@field data_file string Path to the data file
---@field log_file string Path to the log file
M.options = {}

M.setup = function(opts)
  local utils = require('dev-chronicles.utils')

  ---@type chronicles.Options
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})

  local function handle_paths_field(path_field_key, sort)
    local paths_tbl_field = merged[path_field_key]
    if type(paths_tbl_field) == 'string' then
      paths_tbl_field = { paths_tbl_field }
    end
    for i = 1, #paths_tbl_field do
      paths_tbl_field[i] = utils.expand(paths_tbl_field[i])
    end
    if sort then
      table.sort(paths_tbl_field, function(a, b)
        return #a > #b
      end)
    end
    merged[path_field_key] = paths_tbl_field
  end

  handle_paths_field('tracked_parent_dirs', merged.sort_tracked_parent_dirs)
  handle_paths_field('tracked_dirs')
  handle_paths_field('exclude_dirs_absolute')

  local exclude_subdirs_relative_map = {}
  for _, subdir in ipairs(merged.exclude_subdirs_relative) do
    exclude_subdirs_relative_map[subdir] = true
  end
  merged.exclude_subdirs_relative = exclude_subdirs_relative_map

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

  if merged.dashboard.bar_spacing < 0 then
    vim.notify('DevChronicles: bar_spacing should be a positive number')
    return
  end

  if
    merged.dashboard.footer.let_proj_names_extend_bars_by_one and merged.dashboard.bar_spacing < 2
  then
    vim.notify(
      'DevChronicles: if let_proj_names_extend_bars_by_one is set to true then bar_spacing should be at least 2'
    )
    return
  end

  M.options = merged

  require('dev-chronicles.core').init()
end

return M
