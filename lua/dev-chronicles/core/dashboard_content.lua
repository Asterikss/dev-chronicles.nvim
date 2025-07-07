local M = {}

M._colors = {
  'DevChroniclesRed',
  'DevChroniclesBlue',
  'DevChroniclesGreen',
  'DevChroniclesYellow',
  'DevChroniclesMagenta',
  'DevChroniclesCyan',
  'DevChroniclesOrange',
  'DevChroniclesPurple',
}

---Calculates number of projects to keep and the chart starting column
---@param bar_width integer
---@param bar_spacing integer
---@param max_chart_width integer
---@param n_projects integer
---@param win_width integer
---@return integer, integer: n_projects_to_keep, chart_start_col
M.calc_chart_stats = function(bar_width, bar_spacing, max_chart_width, n_projects, win_width)
  -- total_width = k_bars * bar_width + (k_bars - 1) * bar_spacing
  -- k_bars * bar_width + (k_bars - 1) * bar_spacing <= max_chart_width
  -- k_bars * (bar_width + bar_spacing) - bar_spacing <= max_chart_width
  local max_n_bars = math.floor((max_chart_width + bar_spacing) / (bar_width + bar_spacing))
  local n_projects_to_keep = math.min(n_projects, max_n_bars)

  local chart_width = (n_projects_to_keep * bar_width) + ((n_projects_to_keep - 1) * bar_spacing)
  local chart_start_col = math.floor((win_width - chart_width) / 2)

  return n_projects_to_keep, chart_start_col
end

M.set_header_lines_highlights = function(
  lines,
  highlights,
  start_date,
  end_date,
  win_width,
  global_time_filtered,
  total_time_as_hours_max
)
  local utils = require('dev-chronicles.utils')
  local left_header = string.format(
    'Ξ Total Time: %s',
    utils.format_time(global_time_filtered, total_time_as_hours_max)
  )
  local right_header = utils.get_time_period_str(start_date, end_date)
  local header_padding = win_width - #left_header - #right_header
  table.insert(lines, left_header .. string.rep(' ', header_padding) .. right_header)
  table.insert(lines, '')
  table.insert(lines, string.rep('─', win_width))

  table.insert(highlights, { line = 1, col = 0, end_col = -1, hl_group = 'DevChroniclesTitle' })
end

---Parse projects into an array, so that it can be sorted and traversed in
---order, and calculate max_time
---@param projects_filtered_parsed any
---@return table<integer, { id: string, time: integer, last_worked: integer }>
---@return integer
M.parse_projects_calc_max_time = function(projects_filtered_parsed)
  ---@type table<integer, {id: string, time: integer, last_worked: integer}>
  local arr_projects = {}
  local max_time = 0

  for parsed_project_id, parsed_project_data in pairs(projects_filtered_parsed) do
    if parsed_project_data.total_time > max_time then
      max_time = parsed_project_data.total_time
    end
    table.insert(arr_projects, {
      id = parsed_project_id,
      time = parsed_project_data.total_time,
      last_worked = parsed_project_data.last_worked,
    })
  end

  return arr_projects, max_time
end

M.sort_and_filter_projects_to_fit = function(
  arr_projects,
  n_projects_to_keep,
  sort,
  by_last_worked,
  asc
)
  if sort then
    table.sort(arr_projects, function(a, b)
      if by_last_worked then
        if asc then
          return a.last_worked < b.last_worked
        else
          return a.last_worked > b.last_worked
        end
      else
        if asc then
          return a.time < b.time
        else
          return a.time > b.time
        end
      end
    end)
  end

  local len_arr_projects = #arr_projects
  if n_projects_to_keep == len_arr_projects then
    return arr_projects
  end

  local arr_projects_filtered = {}

  if asc then
    for i = math.max(1, len_arr_projects - n_projects_to_keep), len_arr_projects do
      table.insert(arr_projects_filtered, arr_projects[i])
    end
  else
    for i = 1, math.min(n_projects_to_keep, len_arr_projects) do
      table.insert(arr_projects_filtered, arr_projects[i])
    end
  end

  return arr_projects_filtered
end

M._generate_bar = function(height, color_name)
  local bar_lines = {}
  local patterns = { '/', '\\' }

  for i = 1, height do
    -- Alternate between / and \ for crosshatch effect
    local char = patterns[(i % 2) + 1]
    table.insert(bar_lines, char)
  end

  return bar_lines, color_name
end

---@param arr_projects chronicles.Dashboard.ProjectArray
---@param max_time integer
---@param chart_height integer
---@param chart_start_col integer
---@param bar_width integer
---@param bar_spacing integer
---@return chronicles.Dashboard.BarsData, integer
M.create_bars_data = function(
  arr_projects,
  max_time,
  chart_height,
  chart_start_col,
  bar_width,
  bar_spacing
)
  local string_utils = require('dev-chronicles.utils.strings')

  local bars_data = {}
  local max_lines_proj_names = 0

  for i, project in ipairs(arr_projects) do
    local bar_height = math.max(1, math.floor((project.time / max_time) * (chart_height - 4)))
    local color = M._colors[((i - 1) % #M._colors) + 1]
    local bar_lines, bar_color = M._generate_bar(bar_height, color)

    local project_name = string_utils.get_project_name(project.id)
    local project_name_tbl = string_utils.format_project_name(project_name, bar_width)
    max_lines_proj_names = math.max(max_lines_proj_names, #project_name_tbl)

    table.insert(bars_data, {
      project_name_tbl = project_name_tbl,
      project_time = project.time,
      height = bar_height,
      lines = bar_lines,
      color = bar_color,
      start_col = chart_start_col + (i - 1) * (bar_width + bar_spacing),
      width = bar_width,
    })
  end

  return bars_data, max_lines_proj_names
end

---@param lines any
---@param highlights any
---@param bars_data chronicles.Dashboard.BarsData
---@param win_width any
---@param color_proj_times_like_bars any
M.set_time_labels_above_bars = function(
  lines,
  highlights,
  bars_data,
  win_width,
  color_proj_times_like_bars
)
  local utils = require('dev-chronicles.utils')
  local highlights_insert_positon = #lines + 1

  local time_line = {}
  for i = 1, win_width do
    time_line[i] = ' '
  end

  for _, bar in ipairs(bars_data) do
    local time_str = utils.format_time(bar.project_time)
    local len_time_str = #time_str
    local label_start = bar.start_col + math.floor((bar.width - len_time_str) / 2)
    if label_start >= 0 and label_start + len_time_str <= win_width then
      for i = 1, len_time_str do
        time_line[label_start + i] = time_str:sub(i, i)
      end
      if color_proj_times_like_bars then
        table.insert(highlights, {
          line = highlights_insert_positon,
          col = label_start,
          end_col = label_start + len_time_str,
          hl_group = bar.color,
        })
      end
    end
  end

  table.insert(lines, table.concat(time_line))

  if not color_proj_times_like_bars then
    table.insert(highlights, {
      line = highlights_insert_positon,
      col = 0,
      end_col = win_width,
      hl_group = 'DevChroniclesTime',
    })
  end

  table.insert(lines, '')
end

M.set_hline_lines_highlights = function(lines, highlights, win_width, hl_group)
  table.insert(lines, string.rep('▔', win_width)) -- '─'
  table.insert(
    highlights,
    { line = #lines, col = 0, end_col = -1, hl_group = hl_group or 'DevChroniclesLabel' }
  )
end

M.set_project_names_lines_highlights = function(
  lines,
  highlights,
  bars_data,
  max_lines_proj_names,
  win_width
)
  local string_utils = require('dev-chronicles.utils.strings')

  for line_idx = 1, max_lines_proj_names do
    local line_chars = {}
    for i = 1, win_width do
      line_chars[i] = ' '
    end

    local hl_bytes_shift = 0

    for _, bar in ipairs(bars_data) do
      local name_part = bar.project_name_tbl[line_idx]

      if name_part then
        -- The number of display columns the string will occupy in the terminal
        local name_display_width = vim.fn.strdisplaywidth(name_part)
        local name_start = bar.start_col + math.floor((bar.width - name_display_width) / 2)
        local n_bytes_name = #name_part

        -- str_utfindex -> How many Unicode codepoints (characters) are in the string.
        for i = 1, vim.str_utfindex(name_part) do
          local char = string_utils.str_sub(name_part, i, i)
          local pos = name_start + i
          line_chars[pos] = char
        end

        -- Highlights still operate on bytes, so we use hl_bytes_shift to combat that
        table.insert(highlights, {
          line = #lines + 1,
          col = name_start + hl_bytes_shift,
          end_col = name_start + hl_bytes_shift + n_bytes_name,
          hl_group = bar.color,
        })

        hl_bytes_shift = hl_bytes_shift + n_bytes_name - name_display_width
      end
    end

    table.insert(lines, table.concat(line_chars))
  end
end

return M
