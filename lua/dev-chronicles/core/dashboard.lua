local M = {}

---Creates lines and highlights for the dashboard
---@param data chronicles.Dashboard.Data?
---@param win_width integer
---@param win_height integer
---@param dashboard_type chronicles.DashboardType
---@return table, table: Lines, Highlights
M.create_dashboard_content = function(data, win_width, win_height, dashboard_type)
  local lines = {}
  local highlights = {}

  if data == nil then
    table.insert(lines, '')
    table.insert(lines, 'No recent projects found (Loser).')
    table.insert(lines, 'Start coding in your tracked directories!')
    return lines, highlights
  end

  local dashboard_content = require('dev-chronicles.core.dashboard_content')
  local dashboard_opts = require('dev-chronicles.config').options.dashboard
  local dashboard_utils = require('dev-chronicles.utils.dashboard')
  local get_random_from_tbl = require('dev-chronicles.utils').get_random_from_tbl
  local differentiate_projects_by_folder_not_path = require('dev-chronicles.config').options.differentiate_projects_by_folder_not_path

  local dashboard_type_opts
  if dashboard_type == require('dev-chronicles.api').DashboardType.All then
    dashboard_type_opts = dashboard_opts.dashboard_all
  elseif dashboard_type == require('dev-chronicles.api').DashboardType.Days then
    dashboard_type_opts = dashboard_opts.dashboard_days
  else
    dashboard_type_opts = dashboard_opts.dashboard_months
  end

  local chart_height = win_height - 7 -- header_height + footer_height
  local max_chart_width = win_width - 4 -- margins
  local max_bar_height = chart_height - 3 -- projects_time + gap + chart floor

  dashboard_content.set_header_lines_highlights(
    lines,
    highlights,
    data.time_period_str,
    win_width,
    data.global_time_filtered,
    dashboard_type_opts.header.total_time_as_hours_max,
    dashboard_type_opts.header.show_current_session_time,
    dashboard_type_opts.header.total_time_format_str,
    dashboard_type_opts.header.prettify,
    dashboard_type_opts.header.show_global_total_time and data.global_time or nil,
    dashboard_type_opts.header.global_total_time_format_str
  )

  local arr_projects, max_time =
    dashboard_content.parse_projects_calc_max_time(data.projects_filtered_parsed)

  local n_projects_to_keep, chart_start_col = dashboard_content.calc_chart_stats(
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    max_chart_width,
    #arr_projects,
    win_width
  )

  arr_projects = dashboard_content.sort_and_cutoff_projects(
    arr_projects,
    n_projects_to_keep,
    dashboard_type_opts.sorting.enable,
    dashboard_type_opts.sorting.sort_by_last_worked_not_total_time,
    dashboard_type_opts.sorting.ascending
  )

  if dashboard_opts.dynamic_bar_height_months then
    max_bar_height = dashboard_content.calc_max_bar_height(
      max_bar_height,
      dashboard_opts.dynamic_bar_height_months_thresholds,
      max_time
    )
  end

  local bar_repr = get_random_from_tbl(dashboard_opts.bar_chars)
  local bar_representation = dashboard_utils.construct_bar_representation(
    bar_repr,
    dashboard_opts.bar_width,
    dashboard_opts.bar_header_extends_by,
    dashboard_opts.bar_footer_extends_by
  )

  ---@type chronicles.Dashboard.BarData[], integer
  local bars_data, max_lines_proj_names = dashboard_content.create_bars_data(
    arr_projects,
    max_time,
    max_bar_height,
    chart_start_col,
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    dashboard_opts.footer.let_proj_names_extend_bars_by_one,
    dashboard_opts.random_bars_coloring,
    dashboard_opts.bars_coloring_follows_sorting_in_order and dashboard_type_opts.sorting.ascending
      or not dashboard_type_opts.sorting.ascending,
    bar_representation.header.realized_rows,
    differentiate_projects_by_folder_not_path
  )

  dashboard_content.set_time_labels_above_bars(
    lines,
    highlights,
    bars_data,
    win_width,
    dashboard_type_opts.header.color_proj_times_like_bars,
    dashboard_type_opts.header.show_global_time_for_each_project,
    dashboard_type_opts.header.show_global_time_only_if_differs,
    dashboard_type_opts.header.color_global_proj_times_like_bars
  )

  dashboard_content.set_bars_lines_highlights(
    lines,
    highlights,
    bars_data,
    bar_representation,
    dashboard_opts.bar_header_extends_by,
    dashboard_opts.bar_footer_extends_by,
    max_bar_height,
    dashboard_opts.bar_width,
    win_width
  )

  dashboard_content.set_hline_lines_highlights(lines, highlights, win_width)

  dashboard_content.set_project_names_lines_highlights(
    lines,
    highlights,
    bars_data,
    max_lines_proj_names,
    dashboard_opts.footer.let_proj_names_extend_bars_by_one,
    win_width
  )

  return lines, highlights
end

---@param data_file string
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
M.get_dashboard_data_all = function(data_file, show_date_period, show_time, time_period_str)
  local data = require('dev-chronicles.utils.data').load_data(data_file)
  local time = require('dev-chronicles.core.time')
  if not data then
    return nil
  end

  return {
    global_time = data.global_time,
    global_time_filtered = data.global_time,
    projects_filtered_parsed = data.projects,
    time_period_str = time.get_time_period_str_months(
      time.get_month_str(data.tracking_start),
      time.get_month_str(),
      show_date_period,
      show_time,
      time_period_str
    ),
  }
end

---@param data_file string
---@param start_date? string
---@param end_date? string
---@param n_months_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@return chronicles.Dashboard.Data?
M.get_dashboard_data_months = function(
  data_file,
  start_date,
  end_date,
  n_months_by_default,
  show_date_period,
  show_time,
  time_period_str
)
  local time = require('dev-chronicles.core.time')
  local data = require('dev-chronicles.utils.data').load_data(data_file)
  if not data then
    return nil
  end

  start_date = start_date or time.get_previous_month(time.get_month_str(), n_months_by_default)
  end_date = end_date or time.get_month_str()
  local start_ts = time.convert_month_str_to_timestamp(start_date)
  local end_ts = time.convert_month_str_to_timestamp(end_date, true)

  if start_ts > end_ts then
    vim.notify(('DevChronicles Error: start (%s) > end (%s)'):format(start_date, end_date))
    return nil
  end

  local filtered_projects = M._filter_projects_by_period(data.projects, start_ts, end_ts)

  if next(filtered_projects) == nil then
    vim.notify(
      ('DevChronicles: no projects worked on between %s and %s'):format(start_date, end_date)
    )
    return nil
  end

  ---@type chronicles.Dashboard.Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0

  local l_pointer_month, l_pointer_year = time.extract_month_year(start_date)
  local r_pointer_month, r_pointer_year = time.extract_month_year(end_date)

  while true do
    local curr_date_key = string.format('%02d.%d', r_pointer_month, r_pointer_year)
    for project_id, project_data in pairs(filtered_projects) do
      local month_time = project_data.by_month[curr_date_key]
      if month_time ~= nil then
        if not projects_filtered_parsed[project_id] then
          projects_filtered_parsed[project_id] = {
            total_time = 0,
            last_worked = project_data.last_worked,
            first_worked = project_data.first_worked,
            tags_map = project_data.tags_map,
            total_global_time = project_data.total_time,
          }
        end
        local filtered_project = projects_filtered_parsed[project_id]
        filtered_project.total_time = filtered_project.total_time + month_time
        global_time_filtered = global_time_filtered + month_time
      end
    end

    if l_pointer_month == r_pointer_month and l_pointer_year == r_pointer_year then
      break
    end

    r_pointer_month = r_pointer_month - 1
    if r_pointer_month == 0 then
      r_pointer_month = 12
      r_pointer_year = r_pointer_year - 1
    end
  end

  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    projects_filtered_parsed = projects_filtered_parsed,
    time_period_str = time.get_time_period_str_months(
      start_date,
      end_date,
      show_date_period,
      show_time,
      time_period_str
    ),
  }
end

M.get_recent_stats = function(days)
  days = days or 30
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return
  end
  local cutoff_time = utils.get_current_timestamp() - (days * 86400) -- 24 * 60 * 60

  local recent_projects = {}
  for project_id, project_data in pairs(data.projects) do
    if project_data.last_worked >= cutoff_time then
      recent_projects[project_id] = project_data
    end
  end

  return {
    global_time = data.global_time,
    projects = recent_projects,
  }
end

return M
