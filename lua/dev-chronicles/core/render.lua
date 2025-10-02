local M = {}

---@param panel_data chronicles.Panel.Data
---@return integer: buffer
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

  require('dev-chronicles.core.colors').apply_highlights(buf, panel_data.highlights)

  ---@return chronicles.Panel.Context
  local function get_current_context()
    local line_idx = vim.api.nvim_win_get_cursor(win)[1]
    local line_content = vim.api.nvim_buf_get_lines(buf, line_idx - 1, line_idx, false)[1]
    ---@type chronicles.Panel.Context
    return {
      line_idx = line_idx,
      line_content = line_content,
      buf = buf,
      win = win,
    }
  end

  local opts = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  if panel_data.actions then
    for key, callback in pairs(panel_data.actions) do
      vim.keymap.set('n', key, function()
        callback(get_current_context())
      end, opts)
    end
  end

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'dev-chronicles', { buf = buf })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })

  vim.api.nvim_buf_set_name(buf, panel_data.buf_name)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd.redraw()
  return buf
end

return M
