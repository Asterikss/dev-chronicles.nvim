local M = {}

---@type chronicles.Options.DefaultVars
local default_vars = {
  bar_width = 9,
  bar_header_extends_by = 1,
  bar_footer_extends_by = 1,
  bar_spacing = 3,
}

---@type chronicles.Options.Dashboard.Header
local dashboard_section_header_opts = {
  show_date_period = true,
  show_time = true,
  time_period_str = nil,
  time_period_singular_str = nil,
  total_time_as_hours_max = true,
  total_time_as_hours_min = true,
  show_current_session_time = true,
  show_global_time_for_each_project = true,
  show_global_time_only_if_differs = true,
  color_global_proj_times_like_bars = false,
  total_time_format_str = 'total time: %s',
  prettify = true,
  window_title = ' Dev Chronicles ',
  top_projects = {
    enable = true,
    extra_space_between_bars = false,
    use_wide_bars = false,
    min_top_projects_len_to_show = 1,
  },
}

---@type chronicles.Options.Dashboard.Sorting
local dashboard_section_sorting_opts = {
  enable = true,
  sort_by_last_worked_not_total_time = true,
  ascending = true,
}

---@type chronicles.Options.Dashboard.Base
local dashboard_section_base = {
  header = dashboard_section_header_opts,
  sorting = dashboard_section_sorting_opts,
  dynamic_bar_height_thresholds = nil,
  n_by_default = 2,
  proj_total_time_as_hours_max = true,
  proj_total_time_as_hours_min = true,
  random_bars_coloring = false,
  bars_coloring_follows_sorting_in_order = true,
  color_proj_times_like_bars = false,
  min_proj_time_to_display_proj = 0,
  window_border = nil,
  bar_chars = nil,
}

local function make_dashboard_section(opts)
  return vim.tbl_deep_extend(
    'force',
    dashboard_section_base,
    { header = dashboard_section_header_opts },
    { sorting = dashboard_section_sorting_opts },
    opts or {}
  )
end

---@class chronicles.Options
local defaults = {
  tracked_parent_dirs = {},
  tracked_dirs = {},
  exclude_subdirs_relative = {},
  exclude_dirs_absolute = {},
  sort_tracked_parent_dirs = false,
  differentiate_projects_by_folder_not_path = true,
  min_session_time = 180,
  track_days = true,
  extend_today_to_4am = true,
  data_file = 'dev-chronicles.json',
  log_file = 'log.dev-chronicles.log',
  dashboard = {
    bar_width = default_vars.bar_width,
    bar_header_extends_by = default_vars.bar_header_extends_by,
    bar_footer_extends_by = default_vars.bar_footer_extends_by,
    bar_spacing = default_vars.bar_spacing,
    bar_chars = {
      { {}, { '▉' }, {} },
    },
    use_extra_default_dashboard_bar_chars = true,
    footer = {
      let_proj_names_extend_bars_by_one = true,
    },
    dashboard_days = make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Days ',
        time_period_str = 'last %s days',
        time_period_singular_str = 'today',
      },
      n_by_default = 30,
      dynamic_bar_height_thresholds = { 2, 3.5, 5 }, -- It could be a integer[] and integer[][]
    }),
    dashboard_months = make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Months ',
        top_projects = { use_wide_bars = true },
      },
      n_by_default = 2,
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
      dynamic_bar_height_thresholds = nil, -- = { 15, 25, 40 },
    }),
    dashboard_all = make_dashboard_section({
      header = { window_title = ' Dev Chronicles All ' },
      sorting = { sort_by_last_worked_not_total_time = false },
      window_border = { '╳', '━', '╳', '┃', '╳', '━', '╳', '┃' },
    }),
  },
  for_dev_start_time = nil,
  parsed_exclude_subdirs_relative_map = nil,
  extra_default_dashboard_bar_chars = {
    {
      { ' ▼ ' },
      {
        '███████',
        ' █████ ',
        '  ███  ',
        '  ███  ',
        ' █████ ',
        '███████',
      },
      {},
    },
    {
      { ' ╔══▣◎▣══╗ ' },
      { '║       ║' },
      { ' ╚══▣◎▣══╝ ' },
    },
    {
      {
        '    ╔═╗    ',
      },
      {

        '╔⏤⏤╝❀╚⏤⏤╗',
        '╚⏤⏤╗❀╔⏤⏤╝',
      },
      {},
    },
    {
      {
        '   ▃▃  ︸  ',
        '   ▌ ︷    ',
        '▄ ▄▌▄ ▄ ▄ ▄',
        '█████████',
      },
      {
        '▌▌ .    █',
        '▌▌  .󱇛  █',
        '▌▌.   . █',
        '▌▌󱇛  .  █',
        '▌▌ .    █',
        '▌▌    . █',
      },
      { ' ▌▌ 󱠞    █ ' },
    },
  },
}

---@param opts? chronicles.Options
M.setup = function(opts)
  local utils = require('dev-chronicles.utils')

  ---@type chronicles.Options
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})

  local function handle_paths_field(path_field_key, sort)
    local paths_tbl_field = merged[path_field_key]
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

  if not merged.parsed_exclude_subdirs_relative_map then
    ---@type table<string, boolean>
    local parsed_exclude_subdirs_relative_map = {}
    for _, subdir in ipairs(merged.exclude_subdirs_relative) do
      parsed_exclude_subdirs_relative_map[subdir] = true
    end
    merged.parsed_exclude_subdirs_relative_map = parsed_exclude_subdirs_relative_map
  end

  if vim.fn.isabsolutepath(merged.data_file) ~= 1 then
    merged.data_file = vim.fn.stdpath('data') .. '/' .. merged.data_file
  end

  if vim.fn.isabsolutepath(merged.log_file) ~= 1 then
    merged.log_file = vim.fn.stdpath('data') .. '/' .. merged.log_file
  end

  if merged.dashboard.dashboard_months.n_by_default < 1 then
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

  if merged.dashboard.bar_header_extends_by * 2 > merged.dashboard.bar_spacing then
    vim.notify(
      'DevChronicles setup error: dashboard.bar_header_extends_by extends too much given dashboard.bar_spacing'
    )
  end
  if merged.dashboard.bar_footer_extends_by * 2 > merged.dashboard.bar_spacing then
    vim.notify(
      'DevChronicles setup error: dashboard.bar_footer_extends_by extends too much given dashboard.bar_spacing'
    )
  end

  if
    merged.dashboard.use_extra_default_dashboard_bar_chars
    and merged.dashboard.bar_width == default_vars.bar_width
    and merged.dashboard.bar_header_extends_by == default_vars.bar_header_extends_by
    and merged.dashboard.bar_footer_extends_by == default_vars.bar_footer_extends_by
    and merged.dashboard.bar_spacing == default_vars.bar_spacing
  then
    for _, extra_bar_chars in ipairs(merged.extra_default_dashboard_bar_chars) do
      table.insert(merged.dashboard.bar_chars, extra_bar_chars)
    end
  end

  if
    merged.dashboard.dashboard_days.n_by_default > 30
    or merged.dashboard.dashboard_days.n_by_default < 1
  then
    vim.notify(
      'DevChronicles setup error: dashboard.default_n_last_days_shown cannot be grater than 30 and smaller than 1. Setting it to 30'
    )
    merged.dashboard.dashboard_days.n_by_default = 30
  end

  ---@type chronicles.Options
  M.options = merged

  require('dev-chronicles.core').init(M.options.data_file)
end

return M
