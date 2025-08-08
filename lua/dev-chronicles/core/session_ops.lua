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

---@param data_file string
---@param track_days boolean
---@param min_session_time integer
---@param extend_today_to_4am boolean
M.end_session = function(data_file, track_days, min_session_time, extend_today_to_4am)
  local _, session_active =
    require('dev-chronicles.core.state').get_session_info(extend_today_to_4am)
  if not session_active then
    vim.notify('Dev Chronicles Error: Tried to end the session when session in not active')
    return
  end

  if session_active.session_time_seconds >= min_session_time then
    M._record_session(data_file, session_active, track_days)
  end

  require('dev-chronicles.core.state').abort_session()
end

---@param data_file string
---@param session_active chronicles.SessionActive
---@param track_days boolean
M._record_session = function(data_file, session_active, track_days)
  local time = require('dev-chronicles.core.time')
  local data = require('dev-chronicles.utils.data').load_data(data_file)
  if not data then
    vim.notify(
      'DevChronicles Error: Recording the session failed. No data returned from load_data()'
    )
    return
  end

  local canonical_end_ts = session_active.canonical_ts
  local end_ts = session_active.now_ts
  local today_key = session_active.canonical_today_str
  local duration_sec = session_active.session_time_seconds
  local project_id = session_active.project_id

  data.global_time = data.global_time + duration_sec
  data.last_data_write = end_ts

  local project = data.projects[project_id]
  if not project then
    ---@type chronicles.ChroniclesData.ProjectData
    project = {
      total_time = 0,
      first_worked = canonical_end_ts,
      last_worked = end_ts,
      last_worked_canonical = canonical_end_ts,
      by_month = {},
      by_day = {},
      tags_map = {},
    }
    data.projects[project_id] = project
  end

  project.first_worked = math.min(project.first_worked, canonical_end_ts)
  project.total_time = project.total_time + duration_sec
  project.last_worked_canonical = canonical_end_ts
  project.last_worked = end_ts

  local curr_month = time.get_month_str(canonical_end_ts)
  project.by_month[curr_month] = (project.by_month[curr_month] or 0) + duration_sec

  if track_days then
    project.by_day[today_key] = (project.by_day[today_key] or 0) + duration_sec
  end

  require('dev-chronicles.utils.data').save_data(data, data_file)
end

return M
