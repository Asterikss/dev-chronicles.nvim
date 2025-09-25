local M = {}

---@param panel_subtype chronicles.Panel.Subtype
---@param data chronicles.ChroniclesData
---@param opts chronicles.Options
---@param panel_subtype_args chronicles.Panel.Subtype.Args
---@param session_base chronicles.SessionBase
---@param session_time_seconds? integer
---@return chronicles.Panel.Data?
function M.dashboard(
  panel_subtype,
  data,
  opts,
  panel_subtype_args,
  session_base,
  session_time_seconds
)
  local notify = require('dev-chronicles.utils.notify')
  local dashboard_data_extraction = require('dev-chronicles.dashboard.data_extraction')
  local PanelSubtype = require('dev-chronicles.core.enums').PanelSubtype
  local get_window_dimensions = require('dev-chronicles.utils').get_window_dimensions

  local dashboard_stats
  ---@type chronicles.Dashboard.TopProjectsArray?
  local top_projects = nil
  ---@type chronicles.Options.Dashboard.Section
  local dashboard_type_options

  local start_offset = panel_subtype_args.start_offset
  local end_offset = panel_subtype_args.end_offset
  if (start_offset and start_offset < 0) or (end_offset and end_offset < 0) then
    notify.warn('Both start_offset and end_offset cannot be smaller than 0')
    return
  end

  if panel_subtype == PanelSubtype.Days then
    dashboard_type_options = opts.dashboard.dashboard_days
    dashboard_stats, top_projects = dashboard_data_extraction.get_dashboard_data_days(
      data,
      session_base.canonical_today_str,
      start_offset,
      end_offset,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_str_singular,
      dashboard_type_options.header.top_projects.enable
    )
  elseif panel_subtype == PanelSubtype.All then
    dashboard_type_options = opts.dashboard.dashboard_all
    dashboard_stats = dashboard_data_extraction.get_dashboard_data_all(
      data,
      session_base.canonical_month_str,
      session_base.canonical_today_str,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_str_singular
    )
  elseif panel_subtype == PanelSubtype.Months then
    dashboard_type_options = opts.dashboard.dashboard_months
    dashboard_stats, top_projects = dashboard_data_extraction.get_dashboard_data_months(
      data,
      session_base,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_str_singular,
      dashboard_type_options.header.top_projects.enable
    )
  elseif panel_subtype == PanelSubtype.Years then
    dashboard_type_options = opts.dashboard.dashboard_years
    dashboard_stats, top_projects = dashboard_data_extraction.get_dashboard_data_years(
      data,
      session_base,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_str_singular,
      dashboard_type_options.header.top_projects.enable
    )
  else
    notify.warn('Unrecognised panel subtype for a dashboard: ' .. panel_subtype)
    return
  end

  if not dashboard_stats then
    return
  end

  local window_dimensions =
    get_window_dimensions(dashboard_type_options.window_width, dashboard_type_options.window_height)

  local lines, highlights = M.create_dashboard_content(
    dashboard_stats,
    dashboard_type_options,
    window_dimensions.width,
    window_dimensions.height,
    opts,
    top_projects,
    session_time_seconds
  )

  ---@type chronicles.Panel.Data
  return {
    lines = lines,
    highlights = highlights,
    window_dimensions = window_dimensions,
    buf_name = 'Dev Chronicles Dashboard',
    window_title = dashboard_type_options.header.window_title,
    window_boarder = dashboard_type_options.window_border,
  }
end

---Creates lines and highlights tables for the dashboard panel
---@param data chronicles.Dashboard.Data?
---@param dashboard_type_opts chronicles.Options.Dashboard.Section
---@param win_width integer
---@param win_height integer
---@param plugin_opts chronicles.Options
---@param top_projects? chronicles.Dashboard.TopProjectsArray
---@param curr_session_time? integer
---@return string[], chronicles.Highlight[]
function M.create_dashboard_content(
  data,
  dashboard_type_opts,
  win_width,
  win_height,
  plugin_opts,
  top_projects,
  curr_session_time
)
  local dashboard_content = require('dev-chronicles.dashboard.content')
  local dashboard_logic = require('dev-chronicles.dashboard.logic')
  local dashboard_utils = require('dev-chronicles.utils.dashboard')
  local get_random_from_tbl = require('dev-chronicles.utils').get_random_from_tbl
  local dashboard_opts = plugin_opts.dashboard
  local differentiate_projects_by_folder_not_path =
    plugin_opts.differentiate_projects_by_folder_not_path

  local lines = {}
  local highlights = {}

  if not data then
    table[1] = ''
    table[2] = 'Something went wrong. Check logs if needed'
    -- TODO: display logs
    return lines, highlights
  end

  local arr_projects = data.final_project_data_arr
  if arr_projects == nil then
    return dashboard_content.handle_no_projects_lines_hl(
      lines,
      highlights,
      data,
      win_width,
      win_height,
      dashboard_type_opts.header,
      top_projects
    )
  end

  local chart_height = win_height - 7 -- header_height + footer_height
  local max_chart_width = win_width - 4 -- margins
  local vertical_space_for_bars = chart_height - 3 -- projects_time + gap 1 + chart floor
  local max_bar_height = vertical_space_for_bars

  if dashboard_type_opts.min_proj_time_to_display_proj > 0 then
    arr_projects = dashboard_logic.filter_by_min_time(
      arr_projects,
      dashboard_type_opts.min_proj_time_to_display_proj
    )
  end
  local len_arr_projects = #arr_projects

  local n_projects_to_keep, chart_start_col = dashboard_logic.calc_chart_stats(
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    max_chart_width,
    len_arr_projects,
    win_width
  )

  -- Reset len_arr_projects to avoid using stale value later
  arr_projects, len_arr_projects = dashboard_logic.sort_and_cutoff_projects(
    arr_projects,
    len_arr_projects,
    n_projects_to_keep,
    dashboard_type_opts.sorting.enable,
    dashboard_type_opts.sorting.sort_by_last_worked_not_total_time,
    dashboard_type_opts.sorting.ascending
  )

  if len_arr_projects < 1 then
    return dashboard_content.handle_no_projects_lines_hl(
      lines,
      highlights,
      data,
      win_width,
      win_height,
      dashboard_type_opts.header,
      top_projects
    )
  end

  if dashboard_type_opts.dynamic_bar_height_thresholds then
    max_bar_height = dashboard_logic.calc_max_bar_height(
      vertical_space_for_bars,
      dashboard_type_opts.dynamic_bar_height_thresholds,
      data.max_project_time
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
  local bars_data, max_lines_proj_names, project_id_to_color = dashboard_logic.create_bars_data(
    arr_projects,
    data.max_project_time,
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
    data.does_include_curr_date,
    dashboard_type_opts.header,
    curr_session_time,
    top_projects,
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

return M
