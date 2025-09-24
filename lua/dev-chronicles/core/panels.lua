local M = {}

local render = require('dev-chronicles.core.render')

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

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Time',
    window_dimensions = {
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - n_lines) * 0.35),
      width = width,
      height = n_lines,
    },
  })
end

function M.display_project_list(opts)
  local data = require('dev-chronicles.utils.data').load_data(opts.data_file)
  if not data then
    return
  end

  local lines, highlights, lines_idx, width = {}, {}, 0, 0

  for project_id, _ in pairs(data.projects) do
    lines_idx = lines_idx + 1
    lines[lines_idx] = project_id
    width = math.max(width, #project_id)
  end

  local actions = {
    ['?'] = function(_)
      M.show_project_help()
    end,
  }

  table.sort(lines, function(a, b)
    return data.projects[a].total_time > data.projects[b].total_time
  end)

  for i = 1, lines_idx do
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesAccent',
    }
  end

  width = math.floor(width * 1.5)

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List',
    actions = actions,
    window_dimensions = {
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - lines_idx) * 0.35),
      width = width,
      height = lines_idx,
    },
  })
end

function M.show_project_help()
  local help_lines = {
    'Help | Project List',
    '',
    'Keybindings:',
    '  ?     - Show this help',
    '  D     - Mark project for deletion',
    '  I     - Show project information',
    '  q/Esc - Close window',
  }
  local max_width = 0
  for _, line in ipairs(help_lines) do
    max_width = math.max(max_width, #line)
  end

  local title = help_lines[1]
  local title_len = #title
  if title_len < max_width then
    local padding = math.floor((max_width - title_len) / 2)
    help_lines[1] = string.rep(' ', padding) .. title
  end

  local highlights, len_help_lines = {}, #help_lines
  for i = 1, len_help_lines do
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesAccent',
    }
  end

  render.render({
    lines = help_lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List Help',
    window_dimensions = {
      col = math.floor((vim.o.columns - max_width) / 2),
      row = math.floor((vim.o.lines - len_help_lines) / 2),
      width = max_width,
      height = len_help_lines,
    },
  })
end

return M
