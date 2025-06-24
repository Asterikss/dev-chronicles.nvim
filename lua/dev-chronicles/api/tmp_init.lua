local M = {}

function M.dashboard()
  vim.notify('Dashboard functionality not yet implemented')
end

function M.get_stats()
  local utils = require('dev-chronicles.utils')
  return utils.load_data()
end

function M.get_recent_stats(days)
  days = days or 30
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  local cutoff_time = utils.current_timestamp() - (days * 24 * 60 * 60)

  local recent_projects = {}
  for project_id, project_data in pairs(data.projects) do
    if project_data.last_worked >= cutoff_time then
      recent_projects[project_id] = project_data
    end
  end

  return {
    global_time = data.global_time,
    projects = recent_projects,
  }
end

return M
