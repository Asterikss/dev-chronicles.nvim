local M = {}

---@class Session
---@field project_id string | nil
---@field start_time integer | nil
---@field is_tracking boolean

---@type Session
local session = {
  project_id = nil,
  start_time = nil,
  is_tracking = false,
}

M.init = function()
  local dashboard = require('dev-chronicles.core.dashboard')
  local curr_month = require('dev-chronicles.utils').get_current_month()
  local api = require('dev-chronicles')

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
      vim.notify('Usage: :DevChronicles [all|start [end]|info|exit]')
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
        return { 'all', 'exit', curr_month }
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

M.start_session = function()
  local utils = require('dev-chronicles.utils')
  local cwd = vim.fn.getcwd()

  local is_project, project_id = utils.is_project(cwd)

  if is_project then
    session.project_id = project_id
    session.start_time = utils.current_timestamp()
    session.is_tracking = true
  end
end

M.end_session = function()
  local get_current_timestamp = require('dev-chronicles.utils').current_timestamp()
  local options = require('dev-chronicles.config').options

  if not session.is_tracking or not session.project_id or not session.start_time then
    return
  end

  local end_time = get_current_timestamp()
  local session_duration = end_time - session.start_time

  -- Only record if session is longer than minimum session length
  if session_duration >= options.min_session_time then
    M.record_session(session.project_id, session_duration, end_time)
  end

  session.project_id = nil
  session.start_time = nil
  session.is_tracking = false
end

M.record_session = function(project_id, duration, end_time)
  local utils = require('dev-chronicles.utils')
  local data_or_error = utils.load_data()

  if type(data_or_error) == 'string' then
    local f = io.open(vim.fn.stdpath('data') .. '/log.dev-chronicles.log', 'a')
    if f then
      f:write('Error recording a session: ' .. data_or_error)
      f:close()
    end
    return
  end

  data_or_error.global_time = data_or_error.global_time + duration

  if not data_or_error.projects[project_id] then
    data_or_error.projects[project_id] = {
      total_time = 0,
      first_worked = end_time,
      last_worked = end_time,
      by_month = {},
    }
  end

  local project = data_or_error.projects[project_id]
  local curr_month = utils.get_current_month()
  project.total_time = project.total_time + duration
  project.last_worked = end_time
  project.by_month[curr_month] = (project.by_month[curr_month] or 0) + duration

  utils.save_data(data_or_error)
end

---@return Session
M.get_session_info = function()
  return vim.deepcopy(session)
end

return M
