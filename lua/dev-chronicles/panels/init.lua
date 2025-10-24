local M = {}

---@param panel_type chronicles.Panel.Type
---@param panel_subtype chronicles.Panel.Subtype
---@param panel_subtype_args? chronicles.Panel.Subtype.Args
---@param opts? chronicles.Options
function M.panel(panel_type, panel_subtype, panel_subtype_args, opts)
  opts = opts or require('dev-chronicles.config').get_opts()
  local data = require('dev-chronicles.utils.data').load_data(opts.data_file)
  if not data then
    return
  end

  local render = require('dev-chronicles.core.render')
  local PanelType = require('dev-chronicles.core.enums').PanelType
  local get_session_info = require('dev-chronicles.core.state').get_session_info
  local update_chronicles_data_with_curr_session =
    require('dev-chronicles.core.session_ops').update_chronicles_data_with_curr_session

  panel_subtype_args = panel_subtype_args or {}

  local session_base, session_active = get_session_info(opts.extend_today_to_4am)
  if session_active then
    data = update_chronicles_data_with_curr_session(
      vim.deepcopy(data),
      session_active,
      session_base,
      opts.track_days
    )
  end

  ---@type chronicles.Panel.Data?
  local panel_data

  if panel_type == PanelType.Dashboard then
    panel_data = require('dev-chronicles.dashboard').dashboard(
      panel_subtype,
      data,
      opts,
      panel_subtype_args,
      session_base,
      session_active and session_active.session_time_seconds
    )
  end

  if panel_data then
    render.render(panel_data)
  end
end

return M
