local M = {}

function M.display_session_time()
  local format_time = require('dev-chronicles.core.time').format_time
  local _, session_active = require('dev-chronicles.api').get_session_info()

  local lines, width
  if session_active then
    local session_time_str = ' ' .. format_time(session_active.session_time_seconds) .. ' '
    local project_name = ' ' .. session_active.project_name .. ' '
    width = math.max(#session_time_str, #project_name)

    lines = {
      '',
      string.rep(' ', math.floor((width - #session_time_str) / 2)) .. session_time_str,
      '',
      string.rep(' ', math.floor((width - #project_name) / 2)) .. project_name,
      '',
    }
  else
    lines = { '', ' Not working on a tracked project ', '' }
    width = #lines[2]
  end

  local n_lines = #lines
  local highlights = {}
  for i = 1, n_lines do
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesAccent',
    }
  end

  require('dev-chronicles.core.render').render({
    lines = lines,
    highlights = highlights,
    window_dimensions = {
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - n_lines) * 0.35),
      width = width,
      height = n_lines,
    },
  })
end

return M
