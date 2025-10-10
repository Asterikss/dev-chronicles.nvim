local M = {}

local notify = require('dev-chronicles.utils.notify')

---@type chronicles.Options
local options

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
  time_period_str_singular = nil,
  show_current_session_time = true,
  prettify = true,
  window_title = ' Dev Chronicles ',
  total_time = {
    as_hours_max = true,
    as_hours_min = true,
    round_hours_above_one = true,
    format_str = 'total time: %s',
  },
  project_global_time = {
    enable = true,
    show_only_if_differs = true,
    color_like_bars = false,
    as_hours_max = true,
    as_hours_min = true,
    round_hours_above_one = true,
  },
  top_projects = {
    enable = true,
    extra_space_between_bars = false,
    wide_bars = false,
    super_extra_duper_wide_bars = false,
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
  random_bars_coloring = false,
  bars_coloring_follows_sorting_in_order = true,
  min_proj_time_to_display_proj = 0,
  window_height = 0.8,
  window_width = 0.8,
  window_border = nil,
  bar_chars = nil,
  project_total_time = {
    as_hours_max = true,
    as_hours_min = true,
    round_hours_above_one = true,
    color_like_bars = false,
  },
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

---@type chronicles.Options
local defaults = {
  tracked_parent_dirs = {},
  tracked_dirs = {},
  exclude_subdirs_relative = {},
  exclude_dirs_absolute = {},
  sort_tracked_parent_dirs = false,
  differentiate_projects_by_folder_not_path = true,
  min_session_time = 15,
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
    dsh_days_today_force_as_hours_min_false = true,
    footer = {
      let_proj_names_extend_bars_by_one = true,
    },
    dashboard_days = make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Days ',
        time_period_str = 'last %s days',
        time_period_str_singular = 'today',
      },
      n_by_default = 30,
      dynamic_bar_height_thresholds = { 2, 3.5, 5 }, -- It could be a integer[] and integer[][]
    }),
    dashboard_months = make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Months ',
        top_projects = { wide_bars = true },
      },
      n_by_default = 2,
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
      dynamic_bar_height_thresholds = nil, -- = { 15, 25, 40 },
    }),
    dashboard_years = make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Years ',
        top_projects = { super_extra_duper_wide_bars = true },
      },
      n_by_default = -1,
      sorting = { sort_by_last_worked_not_total_time = false },
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
    }),
    dashboard_all = make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles All ',
        total_time_format_str = 'global total time: %s',
        show_current_session_time = false,
      },
      sorting = { sort_by_last_worked_not_total_time = false },
      window_height = 0.85,
      window_width = 1,
      window_border = { '╳', '━', '╳', '┃', '╳', '━', '╳', '┃' },
    }),
  },
  project_list = {
    show_help_hint = true,
  },
  highlights = {
    DevChroniclesAccent = { fg = '#ffffff', bold = true },
    DevChroniclesProjectTime = { fg = '#dddddd', bold = true },
    DevChroniclesGlobalProjectTime = { fg = '#b2bec3', bold = true },
    DevChroniclesGrayedOut = { fg = '#606065', bold = true },
    DevChroniclesLightGray = { fg = '#d3d3d3', bold = true },
    DevChroniclesWindowBG = { bg = '#100E18' },
    DevChroniclesWindowTile = { bg = '#FFC0CB' },
  },
  runtime_opts = {
    for_dev_start_time = nil,
    parsed_exclude_subdirs_relative_map = nil,
  },
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
  },
}

---@param opts? chronicles.Options
function M.setup(opts)
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

  if not merged.runtime_opts.parsed_exclude_subdirs_relative_map then
    ---@type table<string, boolean>
    local parsed_exclude_subdirs_relative_map = {}
    for _, subdir in ipairs(merged.exclude_subdirs_relative) do
      parsed_exclude_subdirs_relative_map[subdir] = true
    end
    merged.runtime_opts.parsed_exclude_subdirs_relative_map = parsed_exclude_subdirs_relative_map
  end

  if vim.fn.isabsolutepath(merged.data_file) ~= 1 then
    merged.data_file = vim.fn.stdpath('data') .. '/dev-chronicles/' .. merged.data_file
  end

  if vim.fn.isabsolutepath(merged.log_file) ~= 1 then
    merged.log_file = vim.fn.stdpath('data') .. '/dev-chronicles/' .. merged.log_file
  end

  vim.fn.mkdir(vim.fn.fnamemodify(merged.data_file, ':h'), 'p')
  vim.fn.mkdir(vim.fn.fnamemodify(merged.log_file, ':h'), 'p')

  if merged.dashboard.dashboard_months.n_by_default < 1 then
    notify.error('n_months_by_default should be greter than 0')
    return
  end

  if merged.dashboard.bar_spacing < 0 then
    notify.error('bar_spacing should be a positive number')
    return
  end

  if
    merged.dashboard.footer.let_proj_names_extend_bars_by_one and merged.dashboard.bar_spacing < 2
  then
    notify.error(
      'if let_proj_names_extend_bars_by_one is set to true then bar_spacing should be at least 2'
    )
    return
  end

  if merged.dashboard.bar_header_extends_by * 2 > merged.dashboard.bar_spacing then
    notify.error('dashboard.bar_header_extends_by extends too much given dashboard.bar_spacing')
    return
  end
  if merged.dashboard.bar_footer_extends_by * 2 > merged.dashboard.bar_spacing then
    notify.error('dashboard.bar_footer_extends_by extends too much given dashboard.bar_spacing')
    return
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
    merged.dashboard.dashboard_days.n_by_default > 60
    or merged.dashboard.dashboard_days.n_by_default < 1
  then
    notify.warn(
      'dashboard.default_n_last_days_shown cannot be grater than 60 and smaller than 1. Setting it to 30'
    )
    merged.dashboard.dashboard_days.n_by_default = 60
  end

  ---@type chronicles.Options
  options = merged

  require('dev-chronicles.core').init(options)
end

---@return chronicles.Options
function M.get_opts()
  return options
end

---@return chronicles.Options
function M.get_default_opts()
  return defaults
end

return M
