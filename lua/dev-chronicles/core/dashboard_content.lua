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

---Adds 3 line header
---@param lines string[]
---@param highlights table<integer>
---@param start_date string 'MM.YYY'
---@param end_date string  'MM.YYY'
---@param win_width integer
---@param global_time_filtered integer
---@param total_time_as_hours_max boolean
---@param show_current_session_time boolean
---@param total_time_format_str string
---@param global_total_time? integer
---@param global_total_time_format_str string
M.set_header_lines_highlights = function(
  lines,
  highlights,
  start_date,
  end_date,
  win_width,
  global_time_filtered,
  total_time_as_hours_max,
  show_current_session_time,
  total_time_format_str,
  global_total_time,
  global_total_time_format_str
)
  local utils = require('dev-chronicles.utils')
  local left_header = string.format(
    total_time_format_str,
    utils.format_time(global_time_filtered, total_time_as_hours_max)
  )

  if show_current_session_time then
    local session_start_time = require('dev-chronicles.core').get_session_info().start_time
    if session_start_time then
      local curr_timestamp = utils.get_current_timestamp()
      local session_time = utils.format_time(curr_timestamp - session_start_time)
      left_header = left_header .. ' (' .. session_time .. ')'
    end
  end

  local right_header = utils.get_time_period_str(start_date, end_date)

  local middle_header = global_total_time
      and string.format(
        global_total_time_format_str,
        utils.format_time(global_total_time, total_time_as_hours_max)
      )
    or nil

  local header_line
  if middle_header then
    local total_length = #left_header + #middle_header + #right_header
    local available_space = win_width - total_length

    local left_space = math.floor(available_space / 2)
    local right_space = available_space - left_space

    header_line = left_header
      .. string.rep(' ', left_space)
      .. middle_header
      .. string.rep(' ', right_space)
      .. right_header
  else
    local header_padding = win_width - #left_header - #right_header
    header_line = left_header .. string.rep(' ', header_padding) .. right_header
  end

  table.insert(lines, header_line)
  table.insert(lines, '')
  M.set_hline_lines_highlights(lines, highlights, win_width, '─', 'DevChroniclesTitle')
  table.insert(highlights, { line = 1, col = 0, end_col = -1, hl_group = 'DevChroniclesTitle' })
end

---Parse projects into an array, so that it can be sorted and traversed in
---order, and calculate maximum time across projects
---@param projects_filtered_parsed chronicles.Dashboard.Stats.ParsedProjects
---@return chronicles.Dashboard.FinalProjectData[], integer
M.parse_projects_calc_max_time = function(projects_filtered_parsed)
  ---@type chronicles.Dashboard.FinalProjectData[]
  local arr_projects = {}
  local max_time = 0

  for parsed_project_id, parsed_project_data in pairs(projects_filtered_parsed) do
    local project_total_time = parsed_project_data.total_time
    max_time = math.max(max_time, project_total_time)
    table.insert(arr_projects, {
      id = parsed_project_id,
      time = project_total_time,
      last_worked = parsed_project_data.last_worked,
      global_time = parsed_project_data.total_global_time,
    })
  end

  return arr_projects, max_time
end

---@param arr_projects chronicles.Dashboard.FinalProjectData[]
---@param n_projects_to_keep integer
---@param sort boolean
---@param by_last_worked boolean
---@param asc boolean
---@return chronicles.Dashboard.FinalProjectData[]
M.sort_and_cutoff_projects = function(arr_projects, n_projects_to_keep, sort, by_last_worked, asc)
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
    for i = math.max(1, len_arr_projects - n_projects_to_keep + 1), len_arr_projects do
      table.insert(arr_projects_filtered, arr_projects[i])
    end
  else
    for i = 1, math.min(n_projects_to_keep, len_arr_projects) do
      table.insert(arr_projects_filtered, arr_projects[i])
    end
  end

  return arr_projects_filtered
end

---Unrolls provided bar representation pattern to match `bar_width`. If it
---fails, returns the fallback bar representation consisting of `@`. Also return
---codepoints counts for all the rows
---@param pattern string[]
---@param bar_width integer
---@return string[], integer[]
M.construct_bar_string_tbl_representation = function(pattern, bar_width)
  local realized_bar_repr = {}
  local bar_rows_codepoints = {}

  for _, row_chars in ipairs(pattern) do
    local display_width = vim.fn.strdisplaywidth(row_chars)
    local n_to_fill_bar_width = bar_width / display_width
    if n_to_fill_bar_width ~= math.floor(n_to_fill_bar_width) then
      vim.notify(
        'provided bar_chars row characters: '
          .. row_chars
          .. ' cannot be smoothly expanded to bar_width='
          .. tostring(bar_width)
          .. ' given their display_width='
          .. tostring(display_width)
          .. '. Falling back to @ bar representation'
      )
      return { string.rep('@', bar_width) }, { bar_width }
    end
    local row = string.rep(row_chars, n_to_fill_bar_width)
    local _, codepointidx = vim.str_utfindex(row)
    table.insert(realized_bar_repr, row)
    table.insert(bar_rows_codepoints, codepointidx)
  end

  return realized_bar_repr, bar_rows_codepoints
end

---@param arr_projects chronicles.Dashboard.FinalProjectData[]
---@param max_time integer
---@param max_bar_height integer
---@param chart_start_col integer
---@param bar_width integer
---@param bar_spacing integer
---@param let_proj_names_extend_bars_by_one boolean
---@return chronicles.Dashboard.BarData[], integer
M.create_bars_data = function(
  arr_projects,
  max_time,
  max_bar_height,
  chart_start_col,
  bar_width,
  bar_spacing,
  let_proj_names_extend_bars_by_one
)
  local string_utils = require('dev-chronicles.utils.strings')

  local bars_data = {}
  local max_lines_proj_names = 0

  for i, project in ipairs(arr_projects) do
    local bar_height = math.max(1, math.floor((project.time / max_time) * max_bar_height))
    local color = M._colors[((i - 1) % #M._colors) + 1]

    local project_name = string_utils.get_project_name(project.id)
    local project_name_tbl = string_utils.format_project_name(
      project_name,
      bar_width + (let_proj_names_extend_bars_by_one and 2 or 0)
    )
    max_lines_proj_names = math.max(max_lines_proj_names, #project_name_tbl)

    table.insert(bars_data, {
      project_name_tbl = project_name_tbl,
      project_time = project.time,
      height = bar_height,
      color = color,
      start_col = chart_start_col + (i - 1) * (bar_width + bar_spacing),
      width = bar_width,
      global_project_time = project.global_time,
    })
  end

  return bars_data, max_lines_proj_names
end

---@param lines string[]
---@param highlights table<integer>
---@param bars_data chronicles.Dashboard.BarData[]
---@param win_width integer
---@param color_proj_times_like_bars boolean
---@param show_global_time_for_each_project boolean
---@param show_global_time_only_if_different boolean
---@param color_global_proj_times_like_bars boolean
---@param dashboard_type DashboardType
M.set_time_labels_above_bars = function(
  lines,
  highlights,
  bars_data,
  win_width,
  color_proj_times_like_bars,
  show_global_time_for_each_project,
  show_global_time_only_if_different,
  color_global_proj_times_like_bars,
  dashboard_type
)
  local format_time = require('dev-chronicles.utils').format_time

  -- If DashboardType is All, then bar.global_project_time will be nil
  show_global_time_for_each_project = show_global_time_for_each_project
    and dashboard_type ~= require('dev-chronicles.api').DashboardType.All

  -- Helper function to place a formatted time string onto a character array.
  ---@param target_line string[]
  ---@param time_to_format integer
  ---@param bar_start_col integer
  ---@param bar_width integer
  ---@param color? string
  ---@param highlights_insert_positon integer
  local function place_label(
    target_line,
    time_to_format,
    bar_start_col,
    bar_width,
    color,
    highlights_insert_positon
  )
    local time_str = format_time(time_to_format)
    local len_time_str = #time_str
    local label_start = bar_start_col + math.floor((bar_width - len_time_str) / 2)

    if label_start >= 0 and label_start + len_time_str <= win_width then
      for i = 1, len_time_str do
        target_line[label_start + i] = time_str:sub(i, i)
      end

      if color then
        table.insert(highlights, {
          line = highlights_insert_positon,
          col = label_start,
          end_col = label_start + len_time_str,
          hl_group = color,
        })
      end
    end
  end

  local highlights_insert_positon = #lines + 1
  local time_line = vim.split(string.rep(' ', win_width), '')

  local global_time_line
  if show_global_time_for_each_project then
    global_time_line = vim.split(string.rep(' ', win_width), '')
  end

  for _, bar in ipairs(bars_data) do
    if global_time_line then
      if not show_global_time_only_if_different or bar.global_project_time ~= bar.project_time then
        place_label(
          global_time_line,
          bar.global_project_time,
          bar.start_col,
          bar.width,
          color_global_proj_times_like_bars and bar.color or nil,
          2
        )
      end
    end

    place_label(
      time_line,
      bar.project_time,
      bar.start_col,
      bar.width,
      color_proj_times_like_bars and bar.color or nil,
      highlights_insert_positon
    )
  end

  if global_time_line then
    lines[2] = table.concat(global_time_line)
    table.insert(highlights, {
      line = 2,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesLabel',
    })
  end

  table.insert(lines, table.concat(time_line))
  if not color_proj_times_like_bars then
    table.insert(highlights, {
      line = highlights_insert_positon,
      col = 0,
      end_col = -1,
      hl_group = 'DevChroniclesTime',
    })
  end

  table.insert(lines, '')
end

---@param lines string[]
---@param highlights table<integer>
---@param bars_data chronicles.Dashboard.BarData[]
---@param realized_bar_repr string[]
---@param bar_rows_codepoints integer[]
---@param max_bar_height integer
---@param win_width integer
M.set_bars_lines_highlights = function(
  lines,
  highlights,
  bars_data,
  realized_bar_repr,
  bar_rows_codepoints,
  max_bar_height,
  win_width
)
  local str_sub = require('dev-chronicles.utils.strings').str_sub
  local len_bar_repr = #realized_bar_repr
  local bar_repr_row_index = 0

  for row = max_bar_height, 1, -1 do
    bar_repr_row_index = (bar_repr_row_index % len_bar_repr) + 1

    local line_chars = vim.split(string.rep(' ', win_width), '')
    local hl_bytes_shift = 0

    for _, bar in ipairs(bars_data) do
      if row <= bar.height then
        local bar_row_str = realized_bar_repr[bar_repr_row_index]

        for i = 1, bar_rows_codepoints[bar_repr_row_index] do
          local idx = bar.start_col + i
          local char = str_sub(bar_row_str, i, i)
          line_chars[idx] = char
        end

        local n_bytes_bar_row_str = #bar_row_str

        -- bar.start_col does not account for multibyte characters and
        -- highlights operate on bytes, so we use hl_bytes_shift to combat that
        table.insert(highlights, {
          line = #lines + 1,
          col = bar.start_col + hl_bytes_shift,
          end_col = bar.start_col + n_bytes_bar_row_str + hl_bytes_shift,
          hl_group = bar.color,
        })

        -- bar.width equals vim.fn.strdisplaywidth(bar_row_str), enforced in
        -- M.construct_bar_string_tbl_representation
        hl_bytes_shift = hl_bytes_shift + n_bytes_bar_row_str - bar.width
      end
    end

    table.insert(lines, table.concat(line_chars))
  end
end

---@param lines string[]
---@param highlights table<integer>
---@param win_width integer
---@param char? string
---@param hl_group? string
M.set_hline_lines_highlights = function(lines, highlights, win_width, char, hl_group)
  table.insert(lines, string.rep(char or '▔', win_width))
  table.insert(
    highlights,
    { line = #lines, col = 0, end_col = -1, hl_group = hl_group or 'DevChroniclesLabel' }
  )
end

---@param lines string[]
---@param highlights string[]
---@param bars_data chronicles.Dashboard.BarData[]
---@param max_lines_proj_names integer
---@param let_proj_names_extend_bars_by_one boolean
---@param win_width integer
M.set_project_names_lines_highlights = function(
  lines,
  highlights,
  bars_data,
  max_lines_proj_names,
  let_proj_names_extend_bars_by_one,
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
        local name_start
        if let_proj_names_extend_bars_by_one then
          name_start = bar.start_col - 1 + math.floor((bar.width + 2 - name_display_width) / 2)
        else
          name_start = bar.start_col + math.floor((bar.width - name_display_width) / 2)
        end
        local n_bytes_name = #name_part

        -- str_utfindex -> How many Unicode codepoints (characters) are in the string.
        -- It actually returns two numbers. First one is used for the loop, but it does
        -- not seems to matter here which one is used
        for i = 1, vim.str_utfindex(name_part) do
          local char = string_utils.str_sub(name_part, i, i)
          local pos = name_start + i
          line_chars[pos] = char
        end

        -- bar.start_col (name_start) does not account for multibyte characters and
        -- highlights operate on bytes, so we use hl_bytes_shift to combat that
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

M.calc_max_bar_height = function(initial_max_bar_height, thresholds, max_time)
  for i, threshold in ipairs(thresholds) do
    if max_time < threshold * 3600 then
      return math.floor((i / (#thresholds + 1)) * initial_max_bar_height)
    end
  end
  return initial_max_bar_height
end

return M
