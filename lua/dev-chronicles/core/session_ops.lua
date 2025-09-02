local M = {}

---@param data chronicles.ChroniclesData
---@param session_active chronicles.SessionActive
---@param session_idle chronicles.SessionIdle
---@return chronicles.ChroniclesData
function M.update_chronicles_data_with_curr_session(data, session_active, session_idle)
  local session_time_sec = session_active.session_time_seconds
  data.global_time = data.global_time + session_time_sec

  local now_ts = session_idle.now_ts
  local canonical_ts = session_idle.canonical_ts
  local today_key = session_idle.canonical_today_str
  local curr_month_key = session_idle.canonical_month_str
  local curr_year_key = session_idle.canonical_year_str
  local current_project = data.projects[session_active.project_id]

  if not current_project then
    ---@type chronicles.ChroniclesData.ProjectData
    current_project = {
      total_time = 0,
      by_day = {},
      by_year = {},
      tags_map = {},
      first_worked = session_active.start_time,
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

  current_project.by_year[curr_year_key].by_month[curr_month_key] = (
    current_project.by_year[curr_year_key].by_month[curr_month_key] or 0
  ) + session_time_sec
  current_project.by_year[curr_year_key].total_time = current_project.by_year[curr_year_key].total_time
    + session_time_sec
  current_project.by_day[today_key] = (current_project.by_day[today_key] or 0) + session_time_sec
  current_project.total_time = current_project.total_time + session_time_sec
  current_project.last_worked = now_ts
  current_project.last_worked_canonical = canonical_ts

  return data
end

---@param data_file string
---@param track_days boolean
---@param min_session_time integer
---@param extend_today_to_4am boolean
function M.end_session(data_file, track_days, min_session_time, extend_today_to_4am)
  local state = require('dev-chronicles.core.state')
  local session_idle, session_active = state.get_session_info(extend_today_to_4am)
  if not session_active then
    return
  end

  if session_active.session_time_seconds >= min_session_time then
    M._record_session(data_file, session_active, session_idle, track_days)
  end

  state.abort_session()
end

---@param data_file string
---@param session_active chronicles.SessionActive
---@param session_idle chronicles.SessionIdle
---@param track_days boolean
function M._record_session(data_file, session_active, session_idle, track_days)
  local data_utils = require('dev-chronicles.utils.data')
  local data = data_utils.load_data(data_file)
  if not data then
    vim.notify(
      'DevChronicles Error: Recording the session failed. No data returned from load_data()'
    )
    return
  end

  local end_ts = session_idle.now_ts
  local canonical_end_ts = session_idle.canonical_ts
  local today_key = session_idle.canonical_today_str
  local month_key = session_idle.canonical_month_str
  local year_key = session_idle.canonical_year_str
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
      by_year = {},
      by_day = {},
      tags_map = {},
    }
    data.projects[project_id] = project
  end

  project.first_worked = math.min(project.first_worked, canonical_end_ts)
  project.total_time = project.total_time + duration_sec
  project.last_worked_canonical = canonical_end_ts
  project.last_worked = end_ts

  local year_data = project.by_year[year_key]
  if not year_data then
    year_data = {
      total_time = 0,
      by_month = {},
    }
    project.by_year[year_key] = year_data
  end

  project.by_year[year_key].by_month[month_key] = (
    project.by_year[year_key].by_month[month_key] or 0
  ) + duration_sec

  project.by_year[year_key].total_time = project.by_year[year_key].total_time + duration_sec

  if track_days then
    project.by_day[today_key] = (project.by_day[today_key] or 0) + duration_sec
  end

  data_utils.save_data(data, data_file)
end

return M
