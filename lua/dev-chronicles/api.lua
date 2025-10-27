local M = {}

---@param panel_type chronicles.Panel.Type
---@param panel_subtype chronicles.Panel.Subtype
---@param panel_subtype_args? chronicles.Panel.Subtype.Args
---@param opts? chronicles.Options
function M.panel(panel_type, panel_subtype, panel_subtype_args, opts)
  require('dev-chronicles.panels').panel(panel_type, panel_subtype, panel_subtype_args, opts)
end

---@param extend_today_to_4am? boolean
---@return chronicles.SessionBase, chronicles.SessionActive?
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

---@param opts? { min_session_time?: number, track_days?: chronicles.Options.TrackDays, extend_today_to_4am?: boolean, data_file?: string }
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

---@param optimize_storage_for_x_days? integer
---@param data_path? string
function M.clean_projects_day_data(optimize_storage_for_x_days, data_path)
  local cleanup_project_day_data =
    require('dev-chronicles.core.session_ops').cleanup_project_day_data
  local data_utils = require('dev-chronicles.utils.data')
  local plugin_opts = require('dev-chronicles.config').get_opts()
  local now_ts = os.time()

  if not optimize_storage_for_x_days then
    if not plugin_opts.track_days.optimize_storage_for_x_days then
      require('dev-chronicles.utils.notify').warn(
        'track_days.optimize_storage_for_x_days is set to nil and it was not passed to the function'
      )
      return
    end
    ---@type integer
    optimize_storage_for_x_days = plugin_opts.track_days.optimize_storage_for_x_days
  end

  data_path = data_path or plugin_opts.data_file

  local data = data_utils.load_data(data_path)
  if not data then
    return
  end

  for _, project_data in pairs(data.projects) do
    cleanup_project_day_data(project_data, optimize_storage_for_x_days, now_ts)
  end

  data_utils.save_data(data, data_path)
end

return M
