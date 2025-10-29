local M = {}

---@param logs_path string?
function M.display_logs(logs_path)
  logs_path = logs_path or require('dev-chronicles.config').get_opts().log_file
  local prefix_line = 'Newest on the bottom. Run `:DevChronicles logs clear` to clear the logs'

  local lines, n_lines, max_width =
    require('dev-chronicles.utils.data').read_file_lines(logs_path, prefix_line)
  if not (lines and n_lines and max_width) then
    return
  end

  local window_title = 'DevChronicles logs'
  if n_lines == 1 then
    lines = { 'Logs empty' }
    max_width = math.max(#lines[1], #window_title + 2)
  end

  require('dev-chronicles.core.render').render({
    buf_name = 'DevChronicles logs',
    lines = lines,
    window_dimensions = require('dev-chronicles.utils').get_window_dimensions_fixed(
      max_width,
      n_lines
    ),
    window_title = window_title,
  })
end

---@param logs_path string
function M.clear_logs(logs_path)
  local notify = require('dev-chronicles.utils.notify')
  local ok, err = require('dev-chronicles.utils.data').clear_file(logs_path)
  if ok then
    notify.notify('Logs cleared')
  else
    notify.error('Failed to clear logs: ' .. err)
  end
end

return M
