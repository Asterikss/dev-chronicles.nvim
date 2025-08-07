local M = {}

M.DashboardType = {
  Days = 'Days',
  Months = 'Months',
  All = 'All',
}

---@param dashboard_type chronicles.DashboardType
---@param data_file string
---@param extend_today_to_4am boolean -- TODO: change this
---@param dashboard_type_args? chronicles.DashboardType.Args
M.dashboard = function(dashboard_type, data_file, extend_today_to_4am, dashboard_type_args)
  local data = require('dev-chronicles.utils.data').load_data(data_file)
  if not data then
    return
  end

  local render = require('dev-chronicles.core.render')
  local dashboard = require('dev-chronicles.dashboard')
  local options = require('dev-chronicles.config').options
  local _, session_active =
    require('dev-chronicles.core.state').get_session_info(extend_today_to_4am)
  if session_active then
    data = require('dev-chronicles.utils.dashboard').update_chronicles_data_with_curr_session(
      data,
      session_active
    )
  end

  dashboard_type_args = dashboard_type_args or {}

  local dashboard_stats
  ---@type chronicles.Dashboard.TopProjectsArray?
  local top_projects = nil
  ---@type chronicles.Options.Dashboard.Section
  local dashboard_type_options

  if dashboard_type == M.DashboardType.Days then
    dashboard_type_options = options.dashboard.dashboard_days
    dashboard_stats, top_projects = dashboard.get_dashboard_data_days(
      data,
      dashboard_type_args.start_offset,
      dashboard_type_args.end_offset,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_singular_str,
      dashboard_type_options.header.top_projects.enable,
      options.extend_today_to_4am
    )
  elseif dashboard_type == M.DashboardType.All then
    dashboard_type_options = options.dashboard.dashboard_all
    dashboard_stats = dashboard.get_dashboard_data_all(
      data,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_singular_str
    )
  elseif dashboard_type == M.DashboardType.Months then
    dashboard_type_options = options.dashboard.dashboard_months
    dashboard_stats, top_projects = dashboard.get_dashboard_data_months(
      data,
      dashboard_type_args.start_date,
      dashboard_type_args.end_date,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str,
      dashboard_type_options.header.time_period_singular_str,
      dashboard_type_options.header.top_projects.enable
    )
  else
    vim.notify('Unrecognised dashboard type: ' .. dashboard_type)
    return
  end

  local window_dimensions = render.get_window_dimensions(0.8, 0.8)

  local lines, highlights = dashboard.create_dashboard_content(
    dashboard_stats,
    window_dimensions.width,
    window_dimensions.height,
    dashboard_type,
    top_projects,
    session_active and session_active.session_time_seconds
  )

  render.render(
    lines,
    highlights,
    window_dimensions,
    dashboard_type_options.header.window_title,
    dashboard_type_options.window_border
  )
end

---@param extend_today_to_4am boolean
---@return chronicles.SessionIdle, chronicles.SessionActive?
M.get_session_info = function(extend_today_to_4am)
  return require('dev-chronicles.core.state').get_session_info(extend_today_to_4am)
end

M.abort_session = function()
  require('dev-chronicles.core.state').abort_session()
  vim.notify('Session aborted')
end

return M
