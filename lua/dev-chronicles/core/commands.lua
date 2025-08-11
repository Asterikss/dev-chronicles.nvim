local M = {}

---@param opts chronicles.Options
M.setup_commands = function(opts)
  M._setup_the_command(opts)
  M._setup_autocmds(opts)
end

---@param opts chronicles.Options
M._setup_the_command = function(opts)
  local api = require('dev-chronicles.api')
  local enums = require('dev-chronicles.core.enums')
  local curr_month = require('dev-chronicles.core.time').get_month_str()

  vim.api.nvim_create_user_command('DevChronicles', function(command_opts)
    local args = command_opts.fargs

    if #args == 0 then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, nil, opts)
    elseif args[1] == 'all' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.All, nil, opts)
    elseif args[1] == 'days' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Days,
        { start_offset = tonumber(args[2]), end_offset = tonumber(args[3]) },
        opts
      )
    elseif args[1] == 'months' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Months,
        { start_date = args[2], end_date = args[3] },
        opts
      )
    elseif args[1] == 'today' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, { start_offset = 0 }, opts)
    elseif args[1] == 'week' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, { start_offset = 6 }, opts)
    elseif args[1] == 'info' then
      local session_idle, session_active = api.get_session_info(opts.extend_today_to_4am)
      vim.notify(
        vim.inspect(
          session_active or vim.tbl_extend('error', session_idle, { is_tracking = false })
        )
      )
    elseif args[1] == 'abort' then
      api.abort_session()
      vim.notify('Session aborted')
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
end

-- -@param data_file string
-- -@param track_days boolean
-- -@param min_session_time integer
-- -@param extend_today_to_4am boolean
-- M._setup_autocmds = function(data_file, track_days, min_session_time, extend_today_to_4am)
---@param opts chronicles.Options
M._setup_autocmds = function(opts)
  local group = vim.api.nvim_create_augroup('DevChronicles', { clear = true })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      require('dev-chronicles.core.state').start_session(opts)
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      require('dev-chronicles.core.session_ops').end_session(
        opts.data_file,
        opts.track_days,
        opts.min_session_time,
        opts.extend_today_to_4am
      )
    end,
  })
end

return M
