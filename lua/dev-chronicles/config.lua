local M = {}

local notify = require('dev-chronicles.utils.notify')
local timeline_cfg = require('dev-chronicles.config.timeline_cfg')
local dashboard_cfg = require('dev-chronicles.config.dashboard_cfg')
local default_dashboard_vars = dashboard_cfg.default_dashboard_vars

---@type chronicles.Options
local options

---@type chronicles.Options
local defaults = {
  tracked_parent_dirs = {},
  tracked_dirs = {},
  exclude_subdirs_relative = {},
  exclude_dirs_absolute = {},
  sort_tracked_parent_dirs = false,
  differentiate_projects_by_folder_not_path = true,
  min_session_time = 15,
  track_days = {
    enable = true,
    optimize_storage_for_x_days = 30,
  },
  extend_today_to_4am = true,
  data_file = 'dev-chronicles.json',
  log_file = 'log.dev-chronicles.log',
  dashboard = {
    bar_width = default_dashboard_vars.bar_width,
    bar_header_extends_by = default_dashboard_vars.bar_header_extends_by,
    bar_footer_extends_by = default_dashboard_vars.bar_footer_extends_by,
    bar_spacing = default_dashboard_vars.bar_spacing,
    bar_chars = {
      { {}, { '▉' }, {} },
    },
    use_extra_default_dashboard_bar_chars = true,
    dsh_days_today_force_precise_time = true,
    footer = {
      let_proj_names_extend_bars_by_one = true,
    },
    dashboard_days = dashboard_cfg.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Days ',
        period_indicator = {
          time_period_str = 'last %s days',
          time_period_str_singular = 'today',
        },
      },
      n_by_default = 30,
      dynamic_bar_height_thresholds = { 2, 3.5, 5 }, -- It could be a integer[] and integer[][]
    }),
    dashboard_months = dashboard_cfg.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Months ',
        top_projects = { wide_bars = true },
      },
      n_by_default = 2,
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
      dynamic_bar_height_thresholds = nil, -- = { 15, 25, 40 },
    }),
    dashboard_years = dashboard_cfg.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Years ',
        top_projects = { super_extra_duper_wide_bars = true },
      },
      n_by_default = -1,
      sorting = { sort_by_last_worked_not_total_time = false },
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
    }),
    dashboard_all = dashboard_cfg.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles All ',
        total_time_format_str = 'global total time: %s',
        show_current_session_time = false,
      },
      sorting = { sort_by_last_worked_not_total_time = false },
      window_height = 0.85,
      window_width = 0.99,
      window_border = { '╳', '━', '╳', '┃', '╳', '━', '╳', '┃' },
    }),
  },
  timeline = {
    row_repr = { '█' },
    timeline_days = timeline_cfg.make_timeline_section({
      n_by_default = 30,
      window_width = 0.85,
      header = {
        period_indicator = {
          time_period_str = 'last %s days',
          time_period_str_singular = 'today',
        },
        window_title = ' Dev Chronicles Timeline Days',
      },
      segment_abbr_labels = {
        date_abbrs = { 'su', 'mo', 'tu', 'we', 'th', 'fr', 'sa' },
      },
    }),
    timeline_months = timeline_cfg.make_timeline_section({
      bar_width = 8,
      n_by_default = 12,
      header = {
        period_indicator = {
          time_period_str = 'last %s months',
          time_period_str_singular = 'this month',
        },
        window_title = ' Dev Chronicles Timeline Months',
      },
    }),
    timeline_years = timeline_cfg.make_timeline_section({
      bar_width = 12,
      n_by_default = 2,
      header = {
        period_indicator = {
          time_period_str = 'last %s years',
          time_period_str_singular = 'this years',
        },
        window_title = ' Dev Chronicles Timeline Years',
      },
      segment_abbr_labels = {
        enable = false,
      },
    }),
    timeline_all = timeline_cfg.make_timeline_section({
      bar_width = 60,
      header = {
        window_title = ' Dev Chronicles Timeline All',
        show_current_session_time = false,
        total_time = {
          format_str = 'global total time: %s',
        },
      },
      segment_numeric_labels = {
        enable = false,
      },
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
    DevChroniclesWindowBG = { bg = '#100e18' },
    DevChroniclesWindowTitle = { fg = '#d3d3d3' },
    DevChroniclesBackupColor = { fg = '#fff588', bold = true },
  },
  runtime_opts = {
    for_dev_state_override = nil,
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
      parsed_exclude_subdirs_relative_map[utils.expand(subdir)] = true
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
    and merged.dashboard.bar_width == default_dashboard_vars.bar_width
    and merged.dashboard.bar_header_extends_by == default_dashboard_vars.bar_header_extends_by
    and merged.dashboard.bar_footer_extends_by == default_dashboard_vars.bar_footer_extends_by
    and merged.dashboard.bar_spacing == default_dashboard_vars.bar_spacing
  then
    for _, extra_bar_chars in ipairs(merged.extra_default_dashboard_bar_chars) do
      table.insert(merged.dashboard.bar_chars, extra_bar_chars)
    end
  end

  if merged.track_days.optimize_storage_for_x_days then
    if merged.track_days.optimize_storage_for_x_days <= 0 then
      notify.error('optimize_storage_for_x_days should be greater than 0')
      return
    end
    if
      merged.dashboard.dashboard_days.n_by_default > merged.track_days.optimize_storage_for_x_days
    then
      notify.error(
        'dashboard.dashboard_days.n_by_default is greater than track_days.optimize_storage_for_x_days. Cannot show older days than previous optimize_storage_for_x_days days. Setting it to the limit'
      )
      merged.dashboard.dashboard_days.n_by_default = merged.track_days.optimize_storage_for_x_days
    end
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
