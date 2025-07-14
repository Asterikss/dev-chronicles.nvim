local M = {}

---Creates lines and highlights for the dashboard
---@param stats chronicles.Dashboard.Stats
---@param win_width integer
---@param win_height integer
---@param dashboard_type DashboardType
---@return table, table: Lines, Highlights
M.create_dashboard_content = function(stats, win_width, win_height, dashboard_type)
  local lines = {}
  local highlights = {}

  if next(stats) == nil then
    table.insert(lines, '')
    table.insert(lines, 'No recent projects found (Loser).')
    table.insert(lines, 'Start coding in your tracked directories!')
    return lines, highlights
  end

  local dashboard_content = require('dev-chronicles.core.dashboard_content')
  local dashboard_opts = require('dev-chronicles.config').options.dashboard
  local dashboard_utils = require('dev-chronicles.utils.dashboard')
  local get_random_from_tbl = require('dev-chronicles.utils').get_random_from_tbl

  local chart_height = win_height - 6 -- header_height + footer_height
  local max_chart_width = win_width - 4 -- margins
  local max_bar_height = chart_height - 3 -- projects_time + gap + chart floor

  dashboard_content.set_header_lines_highlights(
    lines,
    highlights,
    stats.start_date,
    stats.end_date,
    win_width,
    stats.global_time_filtered,
    dashboard_opts.header.total_time_as_hours_max,
    dashboard_opts.header.show_current_session_time,
    dashboard_opts.header.total_time_format_str,
    dashboard_opts.header.show_global_total_time and stats.global_time or nil,
    dashboard_opts.header.global_total_time_format_str
  )

  local arr_projects, max_time =
    dashboard_content.parse_projects_calc_max_time(stats.projects_filtered_parsed)

  local n_projects_to_keep, chart_start_col = dashboard_content.calc_chart_stats(
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    max_chart_width,
    #arr_projects,
    win_width
  )

  local correct_dashboard_sorting_opts = (
    dashboard_type == require('dev-chronicles.api').DashboardType.All
    and dashboard_opts.dashboard_all
  ) or dashboard_opts

  arr_projects = dashboard_content.sort_and_cutoff_projects(
    arr_projects,
    n_projects_to_keep,
    correct_dashboard_sorting_opts.sort,
    correct_dashboard_sorting_opts.sort_by_last_worked_not_total_time,
    correct_dashboard_sorting_opts.ascending
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
    dashboard_opts.bars_coloring_follows_sorting_in_order
        and correct_dashboard_sorting_opts.ascending
      or not correct_dashboard_sorting_opts.ascending,
    bar_representation.header.realized_rows
  )

  dashboard_content.set_time_labels_above_bars(
    lines,
    highlights,
    bars_data,
    win_width,
    dashboard_opts.header.color_proj_times_like_bars,
    dashboard_opts.header.show_global_time_for_each_project,
    dashboard_opts.header.show_global_time_only_if_different,
    dashboard_opts.header.color_global_proj_times_like_bars,
    dashboard_type
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

---Get project stats depending on the DashboardType
---@param dashboard_type DashboardType
---@param start? string  Starting month 'MM.YYYY'
---@param end_? string  End month 'MM.YYYY'
---@return chronicles.Dashboard.Stats
M.get_stats = function(dashboard_type, start, end_)
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return {}
  end

  if dashboard_type == require('dev-chronicles.api').DashboardType.All then
    return {
      global_time = data.global_time,
      global_time_filtered = data.global_time,
      projects_filtered_parsed = data.projects,
      start_date = utils.get_month_str(data.tracking_start),
      end_date = utils.get_month_str(),
    }
  end

  local options = require('dev-chronicles.config').options

  if dashboard_type == require('dev-chronicles.api').DashboardType.Default then
    local curr_month = utils.get_month_str()
    start = utils.get_previous_month(curr_month, options.dashboard.n_months_by_default - 1)
    end_ = curr_month
  end

  if not start or not end_ then
    vim.notify('When displaying custom dashboard both start and end_ date should be set')
    return {}
  end

  -- First filter out all the projects that where not worked on during the chosen period
  ---@type table<string, ProjectData>
  local filtered_projects = {}

  local start_timestamp = utils.convert_month_str_to_timestamp(start)
  local end_timestamp = utils.convert_month_str_to_timestamp(end_, true)

  if start_timestamp > end_timestamp then
    vim.notify('DevChronicles error: start date cannot be greater than end date')
    return {}
  end

  for project_id, project_data in pairs(data.projects) do
    if project_data.first_worked < end_timestamp and project_data.last_worked > start_timestamp then
      filtered_projects[project_id] = project_data
    end
  end

  if next(filtered_projects) == nil then
    vim.notify('DevChronicles: No project data in the specified period')
    return {}
  end

  -- Collect total time for each project in the chosen time period and
  -- last_worked time from the filtered projects
  ---@type chronicles.Dashboard.Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0

  -- start_month -> Month before the target month to account for the loop not being inclusive
  local start_month, start_year = utils.extract_month_year(utils.get_previous_month(start))
  local curr_month, curr_year = utils.extract_month_year(end_)

  while not (start_month == curr_month and start_year == curr_year) do
    local curr_date_key = string.format('%02d.%d', curr_month, curr_year)
    for project_id, project_data in pairs(filtered_projects) do
      local month_time = project_data.by_month[curr_date_key]
      if month_time ~= nil then
        if not projects_filtered_parsed[project_id] then
          projects_filtered_parsed[project_id] = {
            total_time = 0,
            last_worked = project_data.last_worked,
            total_global_time = project_data.total_time,
          }
        end
        local filtered_project = projects_filtered_parsed[project_id]
        filtered_project.total_time = filtered_project.total_time + month_time
        global_time_filtered = global_time_filtered + month_time
      end
    end
    curr_month = curr_month - 1
    if curr_month == 0 then
      curr_month = 12
      curr_year = curr_year - 1
    end
  end

  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    projects_filtered_parsed = projects_filtered_parsed,
    start_date = start,
    end_date = end_,
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
