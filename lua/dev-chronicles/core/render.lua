local M = {}

---@param panel_data chronicles.Panel.Data
function M.render(panel_data)
  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = panel_data.window_dimensions.width,
    height = panel_data.window_dimensions.height,
    row = panel_data.window_dimensions.row,
    col = panel_data.window_dimensions.col,
    style = 'minimal',
    border = panel_data.window_border or 'rounded',
    title = panel_data.window_title,
    title_pos = panel_data.window_title and 'center' or nil,
    focusable = true,
  })

  vim.api.nvim_set_option_value(
    'winhighlight',
    'NormalFloat:DevChroniclesWindowBG,FloatBorder:DevChroniclesLightGray,FloatTitle:DevChroniclesLightGray',
    { win = win }
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, panel_data.lines)

  local ns_id = vim.api.nvim_create_namespace('dev_chronicles_dashboard')
  for _, hl in ipairs(panel_data.highlights) do
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

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'dev-chronicles', { buf = buf })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('readonly', true, { buf = buf })

  vim.api.nvim_buf_set_name(buf, 'Dev Chronicles')
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

return M
