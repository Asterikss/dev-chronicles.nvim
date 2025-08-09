local M = {}

---@param panel_subtype chronicles.Panel.Subtype
---@param data chronicles.ChroniclesData
---@param opts chronicles.Options
---@param panel_subtype_args chronicles.Panel.Subtype.Args
---@param session_idle chronicles.SessionIdle
---@param session_time_seconds? integer
---@return chronicles.Panel.Data?
function M.dashboard(
  panel_subtype,
  data,
  opts,
  panel_subtype_args,
  session_idle,
  session_time_seconds
)
  local get_window_dimensions = require('dev-chronicles.utils').get_window_dimensions
  local PanelSubtype = require('dev-chronicles.core.enums').PanelSubtype

  local dashboard_stats
  ---@type chronicles.Dashboard.TopProjectsArray?
  local top_projects = nil
  ---@type chronicles.Options.Dashboard.Section
  local dashboard_type_options

  if panel_subtype == PanelSubtype.Days then
    dashboard_type_options = opts.dashboard.dashboard_days
    dashboard_stats, top_projects = M.get_dashboard_data_days(
      data,
      session_idle.canonical_today_str,
      panel_subtype_args.start_offset,
      panel_subtype_args.end_offset,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_singular_str,
      dashboard_type_options.header.top_projects.enable
    )
  elseif panel_subtype == PanelSubtype.All then
    dashboard_type_options = opts.dashboard.dashboard_all
    dashboard_stats = M.get_dashboard_data_all(
      data,
      session_idle.canonical_month_str,
      session_idle.canonical_today_str,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_singular_str
    )
  elseif panel_subtype == PanelSubtype.Months then
    dashboard_type_options = opts.dashboard.dashboard_months
    dashboard_stats, top_projects = M.get_dashboard_data_months(
      data,
      session_idle.canonical_month_str,
      session_idle.canonical_today_str,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_singular_str,
      dashboard_type_options.header.top_projects.enable
    )
  else
    vim.notify('Unrecognised panel subtype for dashboard: ' .. panel_subtype)
    return
  end

  local window_dimensions = get_window_dimensions(0.8, 0.8)

  local lines, highlights = M.create_dashboard_content(
    dashboard_stats,
    dashboard_type_options,
    window_dimensions.width,
    window_dimensions.height,
    top_projects,
    session_time_seconds
  )

  ---@type chronicles.Panel.Data
  return {
    lines = lines,
    highlights = highlights,
    window_dimensions = window_dimensions,
    window_title = dashboard_type_options.header.window_title,
    window_boarder = dashboard_type_options.window_border,
  }
end

---Creates lines and highlights tables for the dashboard panel
---@param data chronicles.Dashboard.Data?
---@param dashboard_type_opts chronicles.Options.Dashboard.Section
---@param win_width integer
---@param win_height integer
---@param top_projects? chronicles.Dashboard.TopProjectsArray
---@param curr_session_time? integer
---@return string[], table: Lines, Highlights
M.create_dashboard_content = function(
  data,
  dashboard_type_opts,
  win_width,
  win_height,
  top_projects,
  curr_session_time
)
  local lines = {}
  local highlights = {}

  if not data then
    table.insert(lines, '')
    table.insert(lines, 'No recent projects found (Loser).')
    table.insert(lines, 'Start coding in your tracked directories!')
    return lines, highlights
  end

  local dashboard_content = require('dev-chronicles.dashboard.content')
  local dashboard_opts = require('dev-chronicles.config').get_opts().dashboard
  local dashboard_utils = require('dev-chronicles.utils.dashboard')
  local get_random_from_tbl = require('dev-chronicles.utils').get_random_from_tbl
  local differentiate_projects_by_folder_not_path =
    require('dev-chronicles.config').get_opts().differentiate_projects_by_folder_not_path

  local chart_height = win_height - 7 -- header_height + footer_height
  local max_chart_width = win_width - 4 -- margins
  local vertical_space_for_bars = chart_height - 3 -- projects_time + gap 1 + chart floor
  local max_bar_height = vertical_space_for_bars

  local arr_projects, max_time = dashboard_content.parse_projects_calc_max_time(
    data.projects_filtered_parsed,
    dashboard_type_opts.min_proj_time_to_display_proj
  )

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

  if dashboard_type_opts.dynamic_bar_height_thresholds then
    max_bar_height = dashboard_content.calc_max_bar_height(
      vertical_space_for_bars,
      dashboard_type_opts.dynamic_bar_height_thresholds,
      max_time
    )
  end

  local bar_repr = get_random_from_tbl(
    dashboard_type_opts.bar_chars and dashboard_type_opts.bar_chars or dashboard_opts.bar_chars
  )

  local bar_representation = dashboard_utils.construct_bar_representation(
    bar_repr,
    dashboard_opts.bar_width,
    dashboard_opts.bar_header_extends_by,
    dashboard_opts.bar_footer_extends_by
  )

  ---@type chronicles.Dashboard.BarData[], integer, table<string, string>
  local bars_data, max_lines_proj_names, project_id_to_color = dashboard_content.create_bars_data(
    arr_projects,
    max_time,
    max_bar_height,
    chart_start_col,
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    dashboard_opts.footer.let_proj_names_extend_bars_by_one,
    dashboard_type_opts.random_bars_coloring,
    dashboard_type_opts.bars_coloring_follows_sorting_in_order
        and dashboard_type_opts.sorting.ascending
      or not dashboard_type_opts.sorting.ascending,
    bar_representation.header.realized_rows,
    differentiate_projects_by_folder_not_path
  )

  dashboard_content.set_header_lines_highlights(
    lines,
    highlights,
    data.time_period_str,
    win_width,
    data.global_time_filtered,
    dashboard_type_opts.header.total_time_as_hours_max,
    dashboard_type_opts.header.total_time_as_hours_min,
    dashboard_type_opts.header.show_current_session_time,
    dashboard_type_opts.header.total_time_format_str,
    dashboard_type_opts.header.prettify,
    curr_session_time,
    dashboard_type_opts.header.total_time_round_hours_above_one,
    top_projects,
    dashboard_type_opts.header.top_projects,
    project_id_to_color
  )

  dashboard_content.set_time_labels_above_bars(
    lines,
    highlights,
    bars_data,
    win_width,
    dashboard_type_opts.color_proj_times_like_bars,
    dashboard_type_opts.header.show_global_time_for_each_project,
    dashboard_type_opts.header.show_global_time_only_if_differs,
    dashboard_type_opts.header.color_global_proj_times_like_bars,
    dashboard_type_opts.proj_total_time_as_hours_max,
    dashboard_type_opts.proj_total_time_as_hours_min,
    dashboard_type_opts.proj_total_time_round_hours_above_one,
    dashboard_type_opts.header.proj_global_total_time_round_hours_above_one
  )

  dashboard_content.set_bars_lines_highlights(
    lines,
    highlights,
    bars_data,
    bar_representation,
    dashboard_opts.bar_header_extends_by,
    dashboard_opts.bar_footer_extends_by,
    vertical_space_for_bars,
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

-- TODO: return type
---@param data chronicles.ChroniclesData
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
M.get_dashboard_data_all = function(
  data,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str
)
  local time = require('dev-chronicles.core.time')

  return {
    global_time = data.global_time,
    global_time_filtered = data.global_time,
    projects_filtered_parsed = data.projects,
    time_period_str = time.get_time_period_str_months(
      time.get_month_str(data.tracking_start),
      time.get_month_str(),
      show_date_period,
      show_time,
      time_period_str,
      time_period_singular_str
    ),
  }
end

---@param data chronicles.ChroniclesData
---@param canonical_month_str string
---@param start_date? string
---@param end_date? string
---@param n_months_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
---@param construct_most_worked_on_project_arr boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
M.get_dashboard_data_months = function(
  data,
  canonical_month_str,
  start_date,
  end_date,
  n_months_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str,
  construct_most_worked_on_project_arr
)
  local time = require('dev-chronicles.core.time')

  start_date = start_date or time.get_previous_month(canonical_month_str, n_months_by_default - 1)
  end_date = end_date or canonical_month_str
  local start_ts = time.convert_month_str_to_timestamp(start_date)
  local end_ts = time.convert_month_str_to_timestamp(end_date, true)

  if start_ts > end_ts then
    vim.notify(('DevChronicles Error: start (%s) > end (%s)'):format(start_date, end_date))
    return nil, nil
  end

  local filtered_projects = M._filter_projects_by_period(data.projects, start_ts, end_ts)

  if next(filtered_projects) == nil then
    vim.notify(
      ('DevChronicles: no projects worked on between %s and %s'):format(start_date, end_date)
    )
    return
  end

  ---@type chronicles.Dashboard.Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0
  local most_worked_on_project_per_month = construct_most_worked_on_project_arr and {} or nil

  local l_pointer_month, l_pointer_year = time.extract_month_year(start_date)
  local r_pointer_month, r_pointer_year = time.extract_month_year(end_date)

  local i = 0
  while true do
    i = i + 1
    local month_max_time = 0
    ---@type string|boolean
    local month_max_project = false
    local curr_date_key = string.format('%02d.%d', l_pointer_month, l_pointer_year)

    for project_id, project_data in pairs(filtered_projects) do
      local month_time = project_data.by_month[curr_date_key]
      if month_time then
        local filtered_project_data = projects_filtered_parsed[project_id]
        if not filtered_project_data then
          filtered_project_data = {
            total_time = 0,
            last_worked = project_data.last_worked,
            last_worked_canonical = project_data.last_worked_canonical, -- TODO: This is not used later, remove it after fixing the types. first_worked too
            first_worked = project_data.first_worked,
            tags_map = project_data.tags_map,
            total_global_time = project_data.total_time,
          }
          projects_filtered_parsed[project_id] = filtered_project_data
        end
        filtered_project_data.total_time = filtered_project_data.total_time + month_time
        global_time_filtered = global_time_filtered + month_time

        if construct_most_worked_on_project_arr and month_time > month_max_time then
          month_max_time = month_time
          month_max_project = project_id
        end
      end
    end

    if construct_most_worked_on_project_arr then
      most_worked_on_project_per_month[i] = month_max_project
    end

    if l_pointer_month == r_pointer_month and l_pointer_year == r_pointer_year then
      break
    end

    l_pointer_month = l_pointer_month + 1
    if l_pointer_month == 13 then
      l_pointer_month = 1
      l_pointer_year = l_pointer_year + 1
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
      time_period_str,
      time_period_singular_str
    ),
  },
    most_worked_on_project_per_month
end

---@param data chronicles.ChroniclesData
---@param canonical_today_str string
---@param start_offset? integer
---@param end_offset? integer
---@param n_days_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
---@param construct_most_worked_on_project_arr boolean
---@param extend_today_to_4am boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
M.get_dashboard_data_days = function(
  data,
  canonical_today_str,
  start_offset,
  end_offset,
  n_days_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str,
  construct_most_worked_on_project_arr,
  extend_today_to_4am
)
  local time = require('dev-chronicles.core.time')

  start_offset = start_offset or n_days_by_default - 1
  end_offset = end_offset or 0

  local DAY_SEC = 86400 -- 24 * 60 * 60
  local start_str = time.get_previous_day(canonical_today_str, start_offset)
  local end_str = time.get_previous_day(canonical_today_str, end_offset)
  local start_timestamp = time.convert_day_str_to_timestamp(start_str)
  local end_timestamp = time.convert_day_str_to_timestamp(end_str, true)

  if start_timestamp > end_timestamp then
    vim.notify(('DevChronicles Error: start (%s) > end (%s)'):format(start_str, end_str))
    return
  end

  local filtered_projects =
    M._filter_projects_by_period(data.projects, start_timestamp, end_timestamp)

  if next(filtered_projects) == nil then
    vim.notify(('DevChronicles: no projects worked between %s and %s'):format(start_str, end_str))
    return
  end

  ---@type chronicles.Dashboard.Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0
  local most_worked_on_project_per_day = construct_most_worked_on_project_arr and {} or nil

  local i = 0
  for ts = start_timestamp, end_timestamp, DAY_SEC do
    i = i + 1
    local day_max_time = 0
    ---@type string|boolean
    local day_max_project = false
    local key = time.get_day_str(ts)

    for project_id, project_data in pairs(filtered_projects) do
      local day_time = project_data.by_day[key]
      if day_time then
        local accum_proj_data = projects_filtered_parsed[project_id]
        if not accum_proj_data then
          accum_proj_data = {
            total_time = 0,
            last_worked = project_data.last_worked,
            last_worked_canonical = project_data.last_worked_canonical,
            first_worked = project_data.first_worked,
            tags_map = project_data.tags_map,
            total_global_time = project_data.total_time,
          }
          projects_filtered_parsed[project_id] = accum_proj_data
        end
        accum_proj_data.total_time = accum_proj_data.total_time + day_time
        global_time_filtered = global_time_filtered + day_time

        if construct_most_worked_on_project_arr and day_time > day_max_time then
          day_max_time = day_time
          day_max_project = project_id
        end
      end
    end

    if construct_most_worked_on_project_arr then
      most_worked_on_project_per_day[i] = day_max_project
    end
  end

  ---@type chronicles.Dashboard.Data
  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    projects_filtered_parsed = projects_filtered_parsed,
    time_period_str = time.get_time_period_str_days(
      start_offset - end_offset + 1,
      start_str,
      end_str,
      show_date_period,
      show_time,
      time_period_str,
      time_period_singular_str,
      extend_today_to_4am
    ),
  },
    most_worked_on_project_per_day
end

--- TODO: Set it to nil inplace
---@param projects table<string, chronicles.ChroniclesData.ProjectData>
---@param start_ts integer
---@param end_ts integer
---@return table<string, chronicles.ChroniclesData.ProjectData>
M._filter_projects_by_period = function(projects, start_ts, end_ts)
  local filtered_projects = {}
  for project_id, project_data in pairs(projects) do
    if project_data.first_worked <= end_ts and project_data.last_worked_canonical >= start_ts then
      filtered_projects[project_id] = project_data
    end
  end
  return filtered_projects
end

return M
