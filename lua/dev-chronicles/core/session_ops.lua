local M = {}

---Updates ChroniclesData in place with data from the current session.
---@param data chronicles.ChroniclesData
---@param session_active chronicles.SessionActive
---@param session_base chronicles.SessionBase
---@param track_days boolean
---@return chronicles.ChroniclesData
function M.update_chronicles_data_with_curr_session(data, session_active, session_base, track_days)
  local session_time = session_active.session_time_seconds
  local now_ts = session_base.now_ts
  local canonical_ts = session_base.canonical_ts
  local today_key = session_base.canonical_today_str
  local curr_month_key = session_base.canonical_month_str
  local curr_year_key = session_base.canonical_year_str

  local current_project = data.projects[session_active.project_id]
  if not current_project then
    ---@type chronicles.ChroniclesData.ProjectData
    current_project = {
      total_time = 0,
      by_day = {},
      by_year = {},
      first_worked = now_ts,
      last_worked = now_ts,
      last_worked_canonical = canonical_ts,
    }
    data.projects[session_active.project_id] = current_project
  end

  local year_data = current_project.by_year[curr_year_key]
  if not year_data then
    year_data = {
      total_time = 0,
      by_month = {},
    }
    current_project.by_year[curr_year_key] = year_data
  end

  data.global_time = data.global_time + session_time
  data.last_data_write = now_ts

  current_project.by_year[curr_year_key].by_month[curr_month_key] = (
    current_project.by_year[curr_year_key].by_month[curr_month_key] or 0
  ) + session_time
  current_project.by_year[curr_year_key].total_time = current_project.by_year[curr_year_key].total_time
    + session_time
  current_project.total_time = current_project.total_time + session_time
  current_project.last_worked = now_ts
  current_project.last_worked_canonical = canonical_ts
  current_project.first_worked = math.min(current_project.first_worked, canonical_ts)

  if track_days then
    current_project.by_day[today_key] = (current_project.by_day[today_key] or 0) + session_time
  end

  return data
end

---@param data_file string
---@param track_days boolean
---@param min_session_time integer
---@param extend_today_to_4am boolean
function M.end_session(data_file, track_days, min_session_time, extend_today_to_4am)
  local state = require('dev-chronicles.core.state')
  local session_base, session_active = state.get_session_info(extend_today_to_4am)

  if not session_active and not session_base.changes then
    return
  end

  local data_utils = require('dev-chronicles.utils.data')
  local data = data_utils.load_data(data_file)
  if not data then
    require('dev-chronicles.utils.notify').error(
      'Recording the session failed. No data returned from load_data()'
    )
    return
  end

  if session_active and session_active.session_time_seconds >= min_session_time then
    M.update_chronicles_data_with_curr_session(data, session_active, session_base, track_days)
  end

  if session_base.changes then
    for project_id_to_change, new_color_or_false in pairs(session_base.changes.new_colors or {}) do
      local project_to_change = data.projects[project_id_to_change]
      if project_to_change then
        project_to_change.color = new_color_or_false or nil
      end
    end

    for project_id_to_change, _ in pairs(session_base.changes.to_be_deleted or {}) do
      data.projects[project_id_to_change] = nil
    end
  end

  data_utils.save_data(data, data_file)

  state.abort_session()
end

return M
