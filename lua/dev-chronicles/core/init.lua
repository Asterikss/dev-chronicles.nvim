local M = {}

---@class Session
---@field project_id? string
---@field start_time? integer
---@field is_tracking boolean
local session = {
  project_id = nil,
  start_time = nil,
  is_tracking = false,
}

M.init = function()
  local DashboardType = require('dev-chronicles.api').DashboardType
  local curr_month = require('dev-chronicles.utils').get_month_str()
  local api = require('dev-chronicles.api')

  vim.api.nvim_create_user_command('DevChronicles', function(opts)
    local args = opts.fargs

    if #args == 0 then
      api.dashboard(dashboard.DashboardType.Default)
    elseif args[1] == 'all' then
      api.dashboard(dashboard.DashboardType.All)
    elseif args[1] == 'info' then
      api.get_session_info()
    elseif args[1] == 'exit' then
      api.exit()
    elseif #args == 1 then
      api.dashboard {
        dashboard.DashboardType.Custom,
        start = args[1],
        end_ = args[1],
      }
    elseif #args == 2 then
      api.dashboard {
        dashboard.DashboardType.Custom,
        start = args[1],
        end_ = args[2],
      }
    else
      vim.notify('Usage: :DevChronicles [all|start [end]|info|abort]')
    end
  end, {
    nargs = '*',
    complete = function(
      _ --[[arg_lead]],
      cmd_line,
      _ --[[cursor_pos]]
    )
      local split = vim.split(cmd_line, '%s+')
      if #split == 2 then
        return { 'all', curr_month, 'info', 'exit' }
      end
      return { curr_month }
    end,
  })

  M._setup_autocmds()
end

M._setup_autocmds = function()
  local group = vim.api.nvim_create_augroup('DevChronicles', { clear = true })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      M.start_session()
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.end_session()
    end,
  })
end

---Determine if cwd shoud be tracked. If it should also return its id,
---otherwise return nil. Assumes all paths are absolute and expanded, and all
---dirs end with a slash
---@param cwd string
---@param options chronicles.Options
---@return boolean, string?
M._is_project = function(cwd, options)
  if not cwd:match('/$') then
    cwd = cwd .. '/'
  end

  -- Because both end with a slash, if it matches, it cannot be a different dir with
  -- the same prefix
  for _, exclude_path in ipairs(options.exclude_dirs_absolute) do
    if cwd:find(exclude_path, 1, true) == 1 then
      return false, nil
    end
  end

  for _, dir in ipairs(options.tracked_dirs) do
    if cwd == dir then
      return true, cwd
    end
  end

  -- Only match subdirectories, not the tracked_parent_dirs path itself
  for _, parent_dir in ipairs(options.tracked_parent_dirs) do
    if cwd:find(parent_dir, 1, true) == 1 and cwd ~= parent_dir then
      -- Get the first directory after the parent_dir
      local first_dir = cwd:sub(#parent_dir):match('([^/]+)')
      if first_dir then
        if options.exclude_subdirs_relative[first_dir] then
          return false, nil
        end

        local project_id = parent_dir .. first_dir .. '/'
        return true, require('dev-chronicles.utils').unexpand(project_id)
      end
    end
  end

  return false, nil
end

M.start_session = function()
  local is_project, project_id =
    M._is_project(vim.fn.getcwd(), require('dev-chronicles.config').options)

  if is_project then
    session.project_id = project_id
    session.start_time = require('dev-chronicles.utils').get_current_timestamp()
    session.is_tracking = true
  end
end

M.end_session = function()
  if not session.is_tracking or not session.project_id or not session.start_time then
    return
  end

  local end_time = require('dev-chronicles.utils').get_current_timestamp()
  local session_duration = end_time - session.start_time

  if session_duration >= require('dev-chronicles.config').options.min_session_time then
    M.record_session(session.project_id, session_duration, end_time)
  end

  session.project_id = nil
  session.start_time = nil
  session.is_tracking = false
end

---@param project_id string Project id
---@param duration integer Duration in seconds
---@param end_time integer End timestamp
M.record_session = function(project_id, duration, end_time)
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return
  end

  data.global_time = data.global_time + duration

  if not data.projects[project_id] then
    data.projects[project_id] = {
      total_time = 0,
      first_worked = end_time,
      last_worked = end_time,
      by_month = {},
    }
  end

  local project = data.projects[project_id]
  local curr_month = utils.get_month_str()
  project.total_time = project.total_time + duration
  project.last_worked = end_time
  project.by_month[curr_month] = (project.by_month[curr_month] or 0) + duration

  utils.save_data(data)
end

---@return Session
M.get_session_info = function()
  return vim.deepcopy(session)
end

M.abort_session = function()
  session.is_tracking = false
  session.start_time = nil
  session.project_id = nil
end

return M
