local M = {}

---@param data chronicles.ChroniclesData
---@param session_active chronicles.SessionActive
---@return chronicles.ChroniclesData
M.update_chronicles_data_with_curr_session = function(data, session_active)
  local time = require('dev-chronicles.core.time')

  local session_time_sec = session_active.session_time_seconds
  data.global_time = data.global_time + session_time_sec

  local now_ts = session_active.now_ts
  local today_key = session_active.canonical_today_str
  local canonical_ts = session_active.canonical_ts
  local curr_month_key = time.get_month_str(canonical_ts)
  local current_project = data.projects[session_active.project_id]

  if not current_project then
    ---@type chronicles.ChroniclesData.ProjectData
    current_project = {
      total_time = 0,
      by_day = {},
      by_month = {},
      tags_map = {},
      first_worked = session_active.start_time,
      last_worked = now_ts,
      last_worked_canonical = canonical_ts,
    }
    data.projects[session_active.project_id] = current_project
  end

  current_project.by_day[today_key] = (current_project.by_day[today_key] or 0) + session_time_sec
  current_project.by_month[curr_month_key] = (current_project.by_month[curr_month_key] or 0)
    + session_time_sec
  current_project.total_time = current_project.total_time + session_time_sec
  current_project.last_worked = now_ts
  current_project.last_worked_canonical = canonical_ts

  return data
end

return M
