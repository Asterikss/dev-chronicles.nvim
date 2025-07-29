local M = {}

---@type chronicles.Session
local session = {
  project_id = nil,
  start_time = nil,
  is_tracking = false,
}

---@param data_file string
---@param track_days boolean
---@param min_session_time integer
---@param extend_today_to_4am boolean
M.init = function(data_file, track_days, min_session_time, extend_today_to_4am)
  math.randomseed(os.time())
  local api = require('dev-chronicles.api')
  local curr_month = require('dev-chronicles.core.time').get_month_str()

  vim.api.nvim_create_user_command('DevChronicles', function(opts)
    local args = opts.fargs

    if #args == 0 then
      api.dashboard(api.DashboardType.Days, data_file)
    elseif args[1] == 'all' then
      api.dashboard(api.DashboardType.All, data_file)
    elseif args[1] == 'days' then
      api.dashboard(
        api.DashboardType.Days,
        data_file,
        { start_offset = args[2], end_offset = args[3] }
      )
    elseif args[1] == 'months' then
      api.dashboard(
        api.DashboardType.Months,
        data_file,
        { start_date = args[2], end_date = args[3] }
      )
    elseif args[1] == 'today' then
      api.dashboard(api.DashboardType.Days, data_file, { start_offset = 0 })
    elseif args[1] == 'info' then
      api.get_session_info()
    elseif args[1] == 'abort' then
      api.abort_session()
    else
      vim.notify(
        'Usage: :DevChronicles [all | days [start_offset [end_offset]] |'
          .. 'months [start_date [end_date]] | today | info | abort]'
      )
    end
  end, {
    nargs = '*',
    complete = function(
      _ --[[arg_lead]],
      cmd_line,
      _ --[[cursor_pos]]
    )
      local split = vim.split(cmd_line, '%s+')
      local n_splits = #split
      if n_splits == 2 then
        return { 'all', 'days', 'months', 'info', 'abort' }
      elseif n_splits == 3 then
        if split[2] == 'days' then
          return { '30' }
        elseif split[2] == 'months' then
          return { curr_month }
        end
      end
    end,
  })

  M._setup_autocmds(data_file, track_days, min_session_time, extend_today_to_4am)
end

---@param data_file string
---@param track_days boolean
---@param min_session_time integer
---@param extend_today_to_4am boolean
M._setup_autocmds = function(data_file, track_days, min_session_time, extend_today_to_4am)
  local group = vim.api.nvim_create_augroup('DevChronicles', { clear = true })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      M._start_session()
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.end_session(data_file, track_days, min_session_time, extend_today_to_4am)
    end,
  })
end

---Returns the id of the project if the supplied cwd should be tracked,
---otherwise nil. Assumes all paths are absolute and expanded, and all dirs end
---with a slash.
---@param cwd string
---@param tracked_parent_dirs string[]
---@param tracked_dirs string[]
---@param exclude_dirs_absolute string[]
---@param exclude_subdirs_relative table<string, boolean>
---@param differentiate_projects_by_folder_not_path boolean
---@return string?
M._is_project = function(
  cwd,
  tracked_parent_dirs,
  tracked_dirs,
  exclude_dirs_absolute,
  exclude_subdirs_relative,
  differentiate_projects_by_folder_not_path
)
  if not cwd:match('/$') then
    cwd = cwd .. '/'
  end

  -- Because both end with a slash, if it matches, it cannot be a different dir with
  -- the same prefix
  for _, exclude_path in ipairs(exclude_dirs_absolute) do
    if cwd:find(exclude_path, 1, true) == 1 then
      return nil
    end
  end

  for _, dir in ipairs(tracked_dirs) do
    if cwd == dir then
      if differentiate_projects_by_folder_not_path then
        return require('dev-chronicles.utils.strings').get_project_name(cwd)
      end
      return require('dev-chronicles.utils').unexpand(cwd)
    end
  end

  -- Treat tracked_parent_dirs as excluded paths, so that only the correct
  -- subdirectories are matched
  for _, parent_dir in ipairs(tracked_parent_dirs) do
    if cwd == parent_dir then
      return nil
    end
  end

  for _, parent_dir in ipairs(tracked_parent_dirs) do
    if cwd:find(parent_dir, 1, true) == 1 then
      -- Get the first directory after the parent_dir
      local first_dir = cwd:sub(#parent_dir):match('([^/]+)')
      if first_dir then
        if exclude_subdirs_relative[first_dir] then
          return nil
        end

        if differentiate_projects_by_folder_not_path then
          return first_dir
        end
        local project_id = parent_dir .. first_dir .. '/'
        return require('dev-chronicles.utils').unexpand(project_id)
      end
    end
  end

  return nil
end

M._start_session = function()
  local opts = require('dev-chronicles.config').options
  local project_id = M._is_project(
    vim.fn.getcwd(),
    opts.tracked_parent_dirs,
    opts.tracked_dirs,
    opts.exclude_dirs_absolute,
    opts.exclude_subdirs_relative,
    opts.differentiate_projects_by_folder_not_path
  )

  if project_id then
    session.project_id = project_id
    session.start_time = opts.for_dev_start_time
      or require('dev-chronicles.core.time').get_current_timestamp()
    session.is_tracking = true
  end
end

---@param data_file string
---@param track_days boolean
---@param min_session_time integer
---@param extend_today_to_4am boolean
M.end_session = function(data_file, track_days, min_session_time, extend_today_to_4am)
  local session_info = M.get_session_info()
  if
    not session_info.is_tracking
    or not session_info.project_id
    or not session_info.start_time and session_info.session_time_seconds
  then
    -- TODO:
    vim.notify('Dev Chronicles Error: while ending a session. Some session values that are nil')
    return
  end

  if session_info.session_time_seconds >= min_session_time then
    M._record_session(
      session_info.project_id,
      session_info.session_time_seconds,
      require('dev-chronicles.core.time').get_current_timestamp(),
      track_days,
      extend_today_to_4am,
      data_file
    )
  end

  M.abort_session()
end

--- Never updates first_worked for an existing project, regardless of end_ts
---@param project_id string
---@param duration_sec integer
---@param end_ts integer
---@param track_days boolean
---@param extend_today_to_4am boolean
---@param data_file string
M._record_session = function(
  project_id,
  duration_sec,
  end_ts,
  track_days,
  extend_today_to_4am,
  data_file
)
  local time = require('dev-chronicles.core.time')
  local data = require('dev-chronicles.utils.data').load_data(data_file)
  if not data then
    vim.notify(
      'DevChronicles Error: Recording the session failed. No data returned from load_data()'
    )
    return
  end

  local normalized_end_ts = end_ts
  local day_key = time.get_day_str(end_ts, extend_today_to_4am)
  if day_key ~= time.get_day_str(end_ts) then
    normalized_end_ts = time.convert_day_str_to_timestamp(day_key, true)
  end

  data.global_time = data.global_time + duration_sec
  data.last_data_write = end_ts

  if not data.projects[project_id] then
    data.projects[project_id] = {
      total_time = 0,
      first_worked = normalized_end_ts,
      last_worked = normalized_end_ts,
      last_worked_for_sort = end_ts,
      by_month = {},
      by_day = {},
      tags_map = {},
    }
  end

  local project = data.projects[project_id]
  project.total_time = project.total_time + duration_sec
  project.last_worked = normalized_end_ts
  project.last_worked_for_sort = end_ts

  local curr_month = time.get_month_str(normalized_end_ts)
  project.by_month[curr_month] = (project.by_month[curr_month] or 0) + duration_sec

  if track_days then
    project.by_day[day_key] = (project.by_day[day_key] or 0) + duration_sec
  end

  require('dev-chronicles.utils.data').save_data(data, data_file)
end

---@return chronicles.SessionInfo
M.get_session_info = function()
  local time = require('dev-chronicles.core.time')
  local session_info = vim.deepcopy(session)

  if session_info.start_time then
    local session_time_seconds = time.get_current_timestamp() - session_info.start_time
    session_info.session_time_seconds = session_time_seconds
    session_info.session_time = time.format_time(session_time_seconds)
  end
  return session_info
end

M.abort_session = function()
  session.is_tracking = false
  session.start_time = nil
  session.project_id = nil
end

return M
