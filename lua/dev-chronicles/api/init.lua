local M = {}

M.DashboardType = {
  Days = 'Days',
  Months = 'Months',
  All = 'All',
}

---@param panel_type chronicles.Panel.Type
---@param panel_subtype chronicles.Panel.Subtype
---@param panel_subtype_args? chronicles.Panel.Subtype.Args
---@param opts? chronicles.Options
function M.panel(panel_type, panel_subtype, panel_subtype_args, opts)
  opts = opts or require('dev-chronicles.config').options
  local data = require('dev-chronicles.utils.data').load_data(opts.data_file)
  if not data then
    return
  end

  local render = require('dev-chronicles.core.render')
  local PanelType = require('dev-chronicles.core.enums').PanelType
  local get_session_info = require('dev-chronicles.core.state').get_session_info

  local update_chronicles_data_with_curr_session =
    require('dev-chronicles.utils.dashboard').update_chronicles_data_with_curr_session

  panel_subtype_args = panel_subtype_args or {}

  local _, session_active = get_session_info(opts.extend_today_to_4am)
  ---@type integer?
  local session_time_seconds

  if session_active then
    data = update_chronicles_data_with_curr_session(data, session_active)
    session_time_seconds = session_active.session_time_seconds
  end

  ---@type chronicles.Panel.Data?
  local panel_data

  if panel_type == PanelType.Dashboard then
    vim.notify(panel_subtype)
    panel_data = require('dev-chronicles.dashboard').dashboard(
      panel_subtype,
      data,
      opts,
      session_time_seconds,
      panel_subtype_args
    )
  end

  if panel_data then
    render.render(panel_data)
  end
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
