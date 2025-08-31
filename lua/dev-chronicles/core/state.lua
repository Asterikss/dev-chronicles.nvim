local M = {}

---@type chronicles.SessionState
local session = {
  project_id = nil,
  start_time = nil,
  is_tracking = false,
}

---@param opts chronicles.Options
function M.start_session(opts)
  local project_id, project_name = require('dev-chronicles.core').is_project(
    vim.fn.getcwd(),
    opts.tracked_parent_dirs,
    opts.tracked_dirs,
    opts.exclude_dirs_absolute,
    opts.parsed_exclude_subdirs_relative_map,
    opts.differentiate_projects_by_folder_not_path
  )

  if project_id and project_name then
    session.project_id = project_id
    session.project_name = project_name
    session.start_time = opts.for_dev_start_time or os.time()
    session.is_tracking = true
  end
end

---Return values mimic a tagged union: the first value is always a
---`chronicles.SessionIdle`; the second value is a `chronicles.SessionActive`
---if a session is currently being tracked, otherwise it is `nil`. This is done
---to avoid billions of if checks everywhere. This function is the global source of
---truth (non-pure).
---@param extend_today_to_4am boolean
---@return chronicles.SessionIdle, chronicles.SessionActive?
function M.get_session_info(extend_today_to_4am)
  local time = require('dev-chronicles.core.time')

  local now_ts = os.time()
  local canonical_ts, canonical_today_str =
    time.get_canonical_curr_ts_and_day_str(extend_today_to_4am)

  ---@type chronicles.SessionIdle
  local session_idle = {
    canonical_ts = canonical_ts,
    canonical_today_str = canonical_today_str,
    canonical_month_str = time.get_month_str(canonical_ts),
    now_ts = now_ts,
  }

  if not session.is_tracking then
    return session_idle, nil
  end

  local start_time, project_id, project_name =
    session.start_time, session.project_id, session.project_name
  if not (start_time and project_id and project_name) then
    error(
      "DevChronicles Internal Error: Session's is_tracking is set to true, but its start_time or project_id is missing"
    )
  end

  local session_time_seconds = now_ts - start_time

  ---@type chronicles.SessionActive
  local session_active = {
    project_id = project_id,
    project_name = project_name,
    start_time = start_time,
    session_time_seconds = session_time_seconds,
  }

  return session_idle, session_active
end

function M.abort_session()
  session.is_tracking = false
  session.start_time = nil
  session.project_id = nil
end

return M
