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

  local session_idle, session_active = get_session_info(opts.extend_today_to_4am)
  if session_active then
    data = update_chronicles_data_with_curr_session(data, session_active, session_idle)
  end

  ---@type chronicles.Panel.Data?
  local panel_data

  if panel_type == PanelType.Dashboard then
    panel_data = require('dev-chronicles.dashboard').dashboard(
      panel_subtype,
      data,
      opts,
      panel_subtype_args,
      session_idle,
      session_active and session_active.session_time_seconds
    )
  end

  if panel_data then
    render.render(panel_data)
  end
end

---@param extend_today_to_4am? boolean
---@return chronicles.SessionIdle, chronicles.SessionActive?
function M.get_session_info(extend_today_to_4am)
  extend_today_to_4am = extend_today_to_4am
    or require('dev-chronicles.config').get_opts().extend_today_to_4am
  return require('dev-chronicles.core.state').get_session_info(extend_today_to_4am)
end

---@param opts? chronicles.Options
function M.start_session(opts)
  opts = opts or require('dev-chronicles.config').get_opts()
  require('dev-chronicles.core.state').start_session(opts)
end

function M.abort_session()
  require('dev-chronicles.core.state').abort_session()
end

---@param opts? { min_session_time?: number, track_days?: boolean, extend_today_to_4am?: boolean, data_file?: string }
function M.finish_session(opts)
  opts = opts or {}
  local plugin_opts = require('dev-chronicles.config').get_opts()
  local data_file = opts.data_file or plugin_opts.data_file
  local track_days = opts.track_days or plugin_opts.track_days
  local min_session_time = opts.min_session_time or plugin_opts.min_session_time
  local extend_today_to_4am = opts.extend_today_to_4am or plugin_opts.extend_today_to_4am
  require('dev-chronicles.core.session_ops').end_session(
    data_file,
    track_days,
    min_session_time,
    extend_today_to_4am
  )
end

return M
