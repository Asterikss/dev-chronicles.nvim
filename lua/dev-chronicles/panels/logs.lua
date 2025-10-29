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

  require('dev-chronicles.core.render').render({
    buf_name = 'DevChronicles logs',
    lines = lines,
    window_dimensions = require('dev-chronicles.utils').get_window_dimensions_fixed(
      max_width,
      n_lines
    ),
    window_title = 'DevChronicles logs',
  })
end

return M
