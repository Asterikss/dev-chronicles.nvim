local M = {}

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
      api.dashboard(api.DashboardType.Days, data_file, extend_today_to_4am)
    elseif args[1] == 'all' then
      api.dashboard(api.DashboardType.All, data_file, extend_today_to_4am)
    elseif args[1] == 'days' then
      api.dashboard(
        api.DashboardType.Days,
        data_file,
        extend_today_to_4am,
        { start_offset = tonumber(args[2]), end_offset = tonumber(args[3]) }
      )
    elseif args[1] == 'months' then
      api.dashboard(
        api.DashboardType.Months,
        data_file,
        extend_today_to_4am,
        { start_date = args[2], end_date = args[3] }
      )
    elseif args[1] == 'today' then
      api.dashboard(api.DashboardType.Days, data_file, extend_today_to_4am, { start_offset = 0 })
    elseif args[1] == 'week' then
      api.dashboard(api.DashboardType.Days, data_file, extend_today_to_4am, { start_offset = 6 })
    elseif args[1] == 'info' then
      local session_idle, session_active = api.get_session_info(extend_today_to_4am)
      vim.notify(
        vim.inspect(
          session_active or vim.tbl_extend('error', session_idle, { is_tracking = false })
        )
      )
    elseif args[1] == 'abort' then
      api.abort_session()
    else
      vim.notify(
        'Usage: :DevChronicles [all | days [start_offset [end_offset]] |'
          .. 'months [start_date [end_date]] | today | week | info | abort]'
      )
    end
  end, {
    nargs = '*',
    complete = function(_arg_lead, cmd_line, _cursor_pos)
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
      require('dev-chronicles.core.state').start_session()
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      require('dev-chronicles.core.session_ops').end_session(
        data_file,
        track_days,
        min_session_time,
        extend_today_to_4am
      )
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
---@param parsed_exclude_subdirs_relative_map table<string, boolean>
---@param differentiate_projects_by_folder_not_path boolean
---@return string?
M.is_project = function(
  cwd,
  tracked_parent_dirs,
  tracked_dirs,
  exclude_dirs_absolute,
  parsed_exclude_subdirs_relative_map,
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
        if parsed_exclude_subdirs_relative_map[first_dir] then
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

return M
