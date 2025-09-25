local M = {}

---@param opts chronicles.Options
function M.setup_commands(opts)
  M._setup_the_command(opts)
  M._setup_autocmds(opts)
end

---@param opts chronicles.Options
function M._setup_the_command(opts)
  local api = require('dev-chronicles.api')
  local enums = require('dev-chronicles.core.enums')
  local panels = require('dev-chronicles.core.panels')
  local notify = require('dev-chronicles.utils.notify')

  vim.api.nvim_create_user_command('DevChronicles', function(command_opts)
    local args = command_opts.fargs
    local first_arg = args[1]

    if #args == 0 then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, nil, opts)
    elseif first_arg == 'all' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.All, nil, opts)
    elseif first_arg == 'days' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Days,
        { start_offset = tonumber(args[2]), end_offset = tonumber(args[3]) },
        opts
      )
    elseif first_arg == 'months' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Months,
        { start_date = args[2], end_date = args[3] },
        opts
      )
    elseif first_arg == 'years' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Years,
        { start_date = args[2], end_date = args[3] },
        opts
      )
    elseif first_arg == 'today' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, { start_offset = 0 }, opts)
    elseif first_arg == 'week' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, { start_offset = 6 }, opts)
    elseif first_arg == 'info' then
      local session_base, session_active = api.get_session_info(opts.extend_today_to_4am)
      notify.notify(
        vim.inspect(
          session_active and vim.tbl_extend('error', session_active, session_base)
            or vim.tbl_extend('error', session_base, { is_tracking = false })
        )
      )
    elseif first_arg == 'list' then
      panels.display_project_list(opts)
    elseif first_arg == 'abort' then
      api.abort_session()
      notify.notify('Session aborted')
    elseif first_arg == 'time' then
      panels.display_session_time()
    elseif first_arg == 'finish' then
      api.finish_session()
      notify.notify('Session finished')
    elseif first_arg == 'config' then
      if args[2] == 'default' then
        notify.notify(vim.inspect(require('dev-chronicles.config').get_default_opts()))
      else
        notify.notify(vim.inspect(opts))
      end
    else
      notify.notify(
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
        return { 'all', 'days', 'months', 'info', 'abort', 'time', 'config' }
      elseif n_splits == 3 then
        if split[2] == 'days' then
          return { '30' }
        elseif split[2] == 'months' then
          return { 'MM.YYYY' }
        elseif split[2] == 'years' then
          return { 'YYYY' }
        elseif split[2] == 'config' then
          return { 'default' }
        end
      end
    end,
  })
end

---@param opts chronicles.Options
function M._setup_autocmds(opts)
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
