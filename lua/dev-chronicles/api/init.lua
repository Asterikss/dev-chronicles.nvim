local M = {}

M.DashboardType = {
  Days = 'Days',
  Months = 'Months',
  All = 'All',
}

---@param dashboard_type chronicles.DashboardType
---@param data_file string
---@param dashboard_type_args? chronicles.DashboardType.Args
M.dashboard = function(dashboard_type, data_file, dashboard_type_args)
  local dashboard = require('dev-chronicles.core.dashboard')
  local options = require('dev-chronicles.config').options

  dashboard_type_args = dashboard_type_args or {}

  require('dev-chronicles.core.highlights').setup_highlights()

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local win_width = math.floor(screen_width * 0.8)
  local win_height = math.floor(screen_height * 0.8)
  local win_row = math.floor((screen_height - win_height) / 2)
  local win_col = math.floor((screen_width - win_width) / 2)

  local dashboard_stats
  ---@type chronicles.Options.Dashboard.Section
  local dashboard_type_options

  if dashboard_type == M.DashboardType.Days then
    dashboard_type_options = options.dashboard.dashboard_days
    dashboard_stats = dashboard.get_dashboard_data_days(
      data_file,
      dashboard_type_args.start_offset,
      dashboard_type_args.end_offset,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str
    )
  elseif dashboard_type == M.DashboardType.All then
    dashboard_type_options = options.dashboard.dashboard_all
    dashboard_stats = dashboard.get_dashboard_data_all(
      data_file,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str
    )
  elseif dashboard_type == M.DashboardType.Months then
    dashboard_type_options = options.dashboard.dashboard_months
    dashboard_stats = dashboard.get_dashboard_data_months(
      data_file,
      dashboard_type_args.start_date,
      dashboard_type_args.end_date,
      options.dashboard.dashboard_months.n_by_default,
      dashboard_type_options.header.show_date_period,
      dashboard_type_options.header.show_time,
      dashboard_type_options.header.time_period_str
    )
  else
    vim.notify('Unrecognised dashboard type: ' .. dashboard_type)
    return
  end

  local lines, highlights =
    dashboard.create_dashboard_content(dashboard_stats, win_width, win_height, dashboard_type)

  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = win_row,
    col = win_col,
    style = 'minimal',
    border = dashboard_type_options.window_border or 'rounded',
    title = dashboard_type_options.header.window_title,
    title_pos = 'center',
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local ns_id = vim.api.nvim_create_namespace('dev_chronicles_dashboard')
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      buf,
      ns_id,
      hl.hl_group,
      hl.line - 1, -- Convert to 0-indexed
      hl.col,
      hl.end_col == -1 and -1 or hl.end_col
    )
  end

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  vim.api.nvim_buf_set_name(buf, 'Dev Chronicles Dashboard')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'dev-chronicles-dashboard')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
end

---@return chronicles.SessionInfo
M.get_session_info = function()
  return require('dev-chronicles.core').get_session_info()
end

M.abort_session = function()
  require('dev-chronicles.core').abort_session()
  vim.notify('Session aborted')
end

return M
