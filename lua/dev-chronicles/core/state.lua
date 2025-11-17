local M = {}

---@type chronicles.SessionState
local session = {
  project_id = nil,
  start_time = nil,
  project_name = nil,
  elapsed_so_far = nil,
  changes = nil,
  is_tracking = false,
}

---@param opts chronicles.Options
function M.start_session(opts)
  if opts.runtime_opts.for_dev_state_override then
    session = opts.runtime_opts.for_dev_state_override
    return
  end

  local project_id, project_name = require('dev-chronicles.core').is_project(
    vim.fn.getcwd(),
    opts.tracked_parent_dirs,
    opts.tracked_dirs,
    opts.exclude_dirs_absolute,
    opts.runtime_opts.parsed_exclude_subdirs_relative_map,
    opts.differentiate_projects_by_folder_not_path
  )

  if project_id and project_name then
    session.project_id = project_id
    session.project_name = project_name
    session.start_time = os.time()
    session.is_tracking = true
  end
end

---The first return value (`SessionBase`) is always present and provides the
---baseline context (needed for both displaying and saving data). The second
---return value (`SessionActive`) is present only if a session is currently
---being tracked; it is also used for both displaying and saving. If it is
---`nil`, no session data will be saved. This approach is used to avoid billions of if
---checks. This function is the global source of truth (non-pure).
---@param extend_today_to_4am boolean
---@return chronicles.SessionBase, chronicles.SessionActive?
function M.get_session_info(extend_today_to_4am)
  local time_days = require('dev-chronicles.core.time.days')
  local time_months = require('dev-chronicles.core.time.months')
  local time_years = require('dev-chronicles.core.time.years')

  local now_ts = os.time()
  local canonical_ts, canonical_today_str =
    time_days.get_canonical_curr_ts_and_day_str(extend_today_to_4am)

  ---@type chronicles.SessionBase
  local session_base = {
    canonical_ts = canonical_ts,
    canonical_today_str = canonical_today_str,
    canonical_month_str = time_months.get_month_str(canonical_ts),
    canonical_year_str = time_years.get_year_str(canonical_ts),
    now_ts = now_ts,
    changes = vim.deepcopy(session.changes),
  }

  if not session.is_tracking then
    return session_base, nil
  end

  local project_id, project_name = session.project_id, session.project_name
  if not (project_id and project_name) then
    require('dev-chronicles.utils.notify').fatal(
      "Session is_tracking is set to true, but it's missing project_id or project_name"
    )
    error()
  end

  local session_time = session.elapsed_so_far or 0
  if session.start_time then -- start_time can be nil if the session was paused and not unpaused afterwards
    session_time = session_time + (now_ts - session.start_time)
  end

  ---@type chronicles.SessionActive
  local session_active = {
    project_id = project_id,
    project_name = project_name,
    session_time = session_time,
    start_time = session.start_time,
    elapsed_so_far = session.elapsed_so_far,
    paused = session.start_time == nil or nil,
  }

  return session_base, session_active
end

function M.abort_session()
  session.is_tracking = false
  session.start_time = nil
  session.project_id = nil
  session.project_name = nil
  session.changes = nil
  session.elapsed_so_far = nil
end

---@param changes chronicles.SessionState.Changes
function M.set_changes(changes)
  session.changes = vim.deepcopy(changes)
end

---@return boolean
function M.pause_session()
  if not session.is_tracking or not session.start_time then
    return false
  end
  session.elapsed_so_far = (session.elapsed_so_far or 0) + (os.time() - session.start_time)
  session.start_time = nil
  return true
end

---@return boolean
function M.unpause_session()
  if not session.is_tracking or session.start_time then
    return false
  end
  session.start_time = os.time()
  return true
end

return M
