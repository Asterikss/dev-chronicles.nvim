local M = {}

---@param lines string[]
---@param highlights table
---@param window_dimensions chronicles.WindowDimensions
---@param title? string
---@param border? string[]
M.render = function(lines, highlights, window_dimensions, title, border)
  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = window_dimensions.width,
    height = window_dimensions.height,
    row = window_dimensions.row,
    col = window_dimensions.col,
    style = 'minimal',
    border = border or 'rounded',
    title = title,
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

  vim.api.nvim_buf_set_name(buf, 'Dev Chronicles')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'dev-chronicles')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
end

return M
