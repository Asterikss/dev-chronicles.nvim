local M = {}

local session = {
  project_id = nil,
  start_time = nil,
  is_tracking = false,
}

M.init = function()
  vim.api.nvim_create_user_command('DevChronicles', function()
    require('dev-chronicles').dashboard()
  end, {})

  M.setup_autocmds()
end

M.setup_autocmds = function()
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
  local utils = require('dev-chronicles.utils')
  local config = require('dev-chronicles.config')

  if not session.is_tracking or not session.project_id or not session.start_time then
    return
  end

  local end_time = utils.current_timestamp()
  local session_duration = end_time - session.start_time

  -- Only record if session is longer than minimum session length
  if session_duration >= config.options.min_session_time then
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

  data_or_error.global_time = (data_or_error.global_time or 0) + duration

  if not data_or_error.projects[project_id] then
    data_or_error.projects[project_id] = {
      total_time = 0,
      first_worked = end_time,
      last_worked = end_time,
    }
  end

  local project = data_or_error.projects[project_id]
  project.total_time = project.total_time + duration
  project.last_worked = end_time

  utils.save_data(data_or_error)
end

M.get_session_info = function()
  return vim.deepcopy(session)
end

return M
