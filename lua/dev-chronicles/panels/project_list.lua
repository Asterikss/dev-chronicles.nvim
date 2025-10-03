local M = {}

local colors = require('dev-chronicles.core.colors')
local render = require('dev-chronicles.core.render')
local notify = require('dev-chronicles.utils.notify')

---@class chronicles.ProjectList.Changes
---@field new_colors? table<string, string>
---@field to_be_deleted? table<string, boolean>
M._changes = {}

function M.display_project_list(opts)
  local data = require('dev-chronicles.utils.data').load_data(opts.data_file)
  if not data then
    return
  end

  local lines, highlights, lines_idx, width = {}, {}, 0, 0

  for project_id, _ in pairs(data.projects) do
    lines_idx = lines_idx + 1
    lines[lines_idx] = project_id
  end

  local actions = {
    ['?'] = function(_)
      M._show_project_help()
    end,
    ['I'] = function(context)
      M._show_project_info(data.projects, context)
    end,
    ['C'] = function(context)
      M._change_project_color(data.projects, context)
    end,
    ['D'] = function(context)
      M._mark_project(data.projects, context, 'D', 'DevChroniclesRed', true, function(project_id)
        if not M._changes.to_be_deleted then
          M._changes.to_be_deleted = {}
        end
        if M._changes.to_be_deleted[project_id] == nil then
          M._changes.to_be_deleted[project_id] = true
        else
          M._changes.to_be_deleted[project_id] = nil
        end
      end)
    end,
  }

  table.sort(lines, function(a, b)
    return data.projects[a].total_time > data.projects[b].total_time
  end)

  for i = 1, lines_idx do
    local line = '  ' .. lines[i]
    lines[i] = line
    width = math.max(width, #line)

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

function M._show_project_help()
  local lines = {
    'Help | Project List',
    '',
    'Keybindings:',
    '  I     - Show project information',
    "  C     - Change project's color",
    '  D     - Mark project for deletion',
    '  ?     - Show this help',
    '  q/Esc - Close window',
  }

  local max_width, highlights, n_lines = 0, {}, #lines
  for i = 1, n_lines do
    max_width = math.max(max_width, #lines[i])
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesAccent',
    }
  end

  local title = lines[1]
  local title_len = #title
  if title_len < max_width then
    local padding = math.floor((max_width - title_len) / 2)
    lines[1] = string.rep(' ', padding) .. title
  end

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Help',
    window_dimensions = {
      col = math.floor((vim.o.columns - max_width) / 2),
      row = math.floor((vim.o.lines - n_lines) / 2),
      width = max_width,
      height = n_lines,
    },
  })
end

---@param projects_data chronicles.ChroniclesData.ProjectData[]
---@param context chronicles.Panel.Context
function M._show_project_info(projects_data, context)
  local format_time = require('dev-chronicles.core.time').format_time
  local get_day_str = require('dev-chronicles.core.time.days').get_day_str

  local project_data = projects_data[context.line_content:sub(3)]
  if not project_data then
    return
  end

  local tags = {}
  for tag, _ in pairs(project_data.tags_map) do
    table.insert(tags, tag)
  end

  local lines = {
    'total time:   ' .. format_time(project_data.total_time),
    'first worked: ' .. get_day_str(project_data.first_worked),
    'last_worked:  ' .. get_day_str(project_data.last_worked),
    'color:        ' .. tostring(project_data.color),
    'tags:         ' .. table.concat(tags, ', '),
  }

  local highlights, n_lines, max_width = {}, #lines, 0
  for i = 1, n_lines do
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesAccent',
    }
    max_width = math.max(max_width, #lines[i])
  end

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Project Info',
    window_dimensions = {
      col = math.floor((vim.o.columns - max_width) / 2),
      row = math.floor((vim.o.lines - n_lines) / 2),
      width = max_width,
      height = n_lines,
    },
  })
end

---@param data_projects chronicles.ChroniclesData.ProjectData[]
---@param context chronicles.Panel.Context
---@param symbol string: char
---@param hl_name string
---@param toggle_selection boolean
---@param callback? function
function M._mark_project(data_projects, context, symbol, hl_name, toggle_selection, callback)
  local project_name = context.line_content:sub(3)

  local marked_line
  if toggle_selection and context.line_content:sub(1, 1) == symbol then
    marked_line = '  ' .. project_name
  else
    marked_line = symbol .. ' ' .. project_name
  end

  vim.api.nvim_set_option_value('modifiable', true, { buf = context.buf })
  vim.api.nvim_buf_set_lines(
    context.buf,
    context.line_idx - 1,
    context.line_idx,
    false,
    { marked_line }
  )
  vim.api.nvim_set_option_value('modifiable', false, { buf = context.buf })

  if data_projects[project_name].color then
    colors.apply_highlight_hex(
      context.buf,
      data_projects[project_name].color,
      context.line_idx - 1,
      2,
      -1
    )
  else
    colors.apply_highlight(context.buf, 'DevChroniclesAccent', context.line_idx - 1, 2, -1)
  end
  colors.apply_highlight(context.buf, hl_name, context.line_idx - 1, 0, 1)

  if callback then
    callback(project_name)
  end
end

---@param data_projects chronicles.ChroniclesData.ProjectData[]
---@param context chronicles.Panel.Context
function M._change_project_color(data_projects, context)
  local project_name = context.line_content:sub(3)
  local project_data = data_projects[project_name]

  if not project_data then
    return
  end

  local current_color, new_color = project_data.color, nil
  local current_color_line_default, current_color_line_index, current_color_line_default_text_end =
    'Current:  ', 4, 9
  local new_color_line_default, new_color_line_index, new_color_line_default_text_end =
    'New:      ', 5, 4

  local lines = {
    project_name .. ' — Change Color',
    '',
    '',
    current_color_line_default
      .. (current_color and '#' .. current_color .. '  ████████' or 'None'),
    new_color_line_default,
    '',
    '',
    'Input "nil" to remove the existing color',
    'Press C to change the color again',
    'Press Enter to confirm',
    'Press q/Esc to cancel',
  }

  local n_lines, max_width, highlights = #lines, 0, {}
  for i = 1, n_lines do
    max_width = math.max(max_width, #lines[i])
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesAccent',
    }
  end

  if current_color then
    highlights[n_lines + 1] = {
      line = current_color_line_index,
      col = current_color_line_default_text_end,
      end_col = -1,
      hl_group = colors._get_or_create_highlight(current_color),
    }
  end

  local function prompt(buf)
    vim.ui.input({
      prompt = 'Enter new hex color: ',
    }, function(user_input)
      if not user_input then
        return
      end
      local hex_candidate = colors.check_and_normalize_hex_color(user_input)
      local new_color_line = new_color_line_default

      if hex_candidate then
        new_color_line = new_color_line .. '#' .. hex_candidate .. '  ████████'
        new_color = hex_candidate
      else
        new_color_line = new_color_line .. 'Not a color: ' .. user_input
      end

      vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
      vim.api.nvim_buf_set_lines(
        buf,
        new_color_line_index - 1,
        new_color_line_index,
        false,
        { new_color_line }
      )
      vim.api.nvim_set_option_value('modifiable', false, { buf = buf })

      if hex_candidate then
        colors.apply_highlight_hex(
          buf,
          hex_candidate,
          new_color_line_index - 1,
          new_color_line_default_text_end,
          -1
        )

        colors.apply_highlight(
          buf,
          'DevChroniclesAccent',
          new_color_line_index - 1,
          0,
          new_color_line_default_text_end
        )
      else
        colors.apply_highlight(buf, 'DevChroniclesAccent', new_color_line_index - 1, 0, -1)
      end
    end)
  end

  local function confirm_new_color(win)
    if not M._changes.new_colors then
      M._changes.new_colors = {}
    end
    M._changes.new_colors[project_name] = new_color
    vim.api.nvim_win_close(win, true)
    data_projects[project_name].color = new_color
    M._mark_project(data_projects, context, 'C', 'DevChroniclesBlue', false)
  end

  local buf = render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Change Project Color',
    actions = {
      ['C'] = function(window_context)
        prompt(window_context.buf)
      end,
      ['<CR>'] = function(window_context)
        confirm_new_color(window_context.win)
      end,
    },
    window_dimensions = {
      col = math.floor((vim.o.columns - max_width) / 2),
      row = math.floor((vim.o.lines - n_lines) / 2),
      width = max_width,
      height = n_lines,
    },
  })

  prompt(buf)
end

return M
