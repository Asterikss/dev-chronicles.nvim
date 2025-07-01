local M = {}

M.DashboardType = {
  Default = 'Default',
  Custom = 'Custom',
  All = 'All',
}

---Create DevChronicles dashboard
---@param dashboard_type DashboardType
---@param start? string 'MM.YYYY'
---@param end_? string 'MM.YYYY'
function M.dashboard(dashboard_type, start, end_)
  local dashboard = require('dev-chronicles.core.dashboard')

  require('dev-chronicles.core.highlights').setup_highlights()

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local win_width = math.floor(screen_width * 0.8)
  local win_height = math.floor(screen_height * 0.8)
  local win_row = math.floor((screen_height - win_height) / 2)
  local win_col = math.floor((screen_width - win_width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = win_row,
    col = win_col,
    style = 'minimal',
    border = 'rounded',
    title = ' Dev Chronicles ',
    title_pos = 'center',
  })

  local stats = dashboard.get_stats(dashboard_type, start, end_)
  local lines, highlights = dashboard.create_dashboard_content(stats, win_width, win_height)

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
  vim.api.nvim_win_set_cursor(win, { 2, 1 })
end

M.get_session_info = function()
  vim.notify(vim.inspect(require('dev-chronicles.core').get_session_info()))
end

return M
