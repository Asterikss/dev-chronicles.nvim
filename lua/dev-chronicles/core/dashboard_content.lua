local M = {}

M._colors = {
  'DevChroniclesRed',
  'DevChroniclesBlue',
  'DevChroniclesPurple',
  'DevChroniclesGreen',
  'DevChroniclesYellow',
  'DevChroniclesMagenta',
  'DevChroniclesLightPurple',
  'DevChroniclesOrange',
}

M.BarLevel = {
  Header = 'Header',
  Body = 'Body',
  Footer = 'Footer',
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

---@param arr_projects chronicles.Dashboard.FinalProjectData[]
---@param max_time integer
---@param max_bar_height integer
---@param chart_start_col integer
---@param bar_width integer
---@param bar_spacing integer
---@param let_proj_names_extend_bars_by_one boolean
---@param random_bars_coloring boolean
---@param projects_sorted_ascending boolean
---@param bar_header_realized_rows_tbl string[]
---@return chronicles.Dashboard.BarData[], integer
M.create_bars_data = function(
  arr_projects,
  max_time,
  max_bar_height,
  chart_start_col,
  bar_width,
  bar_spacing,
  let_proj_names_extend_bars_by_one,
  random_bars_coloring,
  projects_sorted_ascending,
  bar_header_realized_rows_tbl
)
  local string_utils = require('dev-chronicles.utils.strings')
  local shuffle = require('dev-chronicles.utils').shuffle

  local bars_data = {}
  local max_lines_proj_names = 0
  local n_projects = #arr_projects
  local colors = M._colors
  local n_colors = #colors
  local color_index

  if random_bars_coloring then
    colors = vim.deepcopy(M._colors)
    shuffle(colors)
    color_index = 1
  end

  for i, project in ipairs(arr_projects) do
    local bar_height = math.max(1, math.floor((project.time / max_time) * max_bar_height))

    local color
    if random_bars_coloring then
      -- All colors were used
      if color_index > n_colors then
        shuffle(colors)
        color_index = 1
      end
      color = colors[color_index]
      color_index = color_index + 1
    else
      color = projects_sorted_ascending and colors[((n_projects - i) % n_colors) + 1]
        or colors[((i - 1) % n_colors) + 1]
    end

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
      current_bar_level = (next(bar_header_realized_rows_tbl) ~= nil) and M.BarLevel.Header
        or M.BarLevel.Body,
      curr_bar_representation_index = 1,
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
---@param show_global_time_only_if_differs boolean
---@param color_global_proj_times_like_bars boolean
M.set_time_labels_above_bars = function(
  lines,
  highlights,
  bars_data,
  win_width,
  color_proj_times_like_bars,
  show_global_time_for_each_project,
  show_global_time_only_if_differs,
  color_global_proj_times_like_bars
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
      if
        bar.global_project_time
        and (not show_global_time_only_if_differs or bar.global_project_time ~= bar.project_time)
      then
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
---@param highlights table<string, any>[]
---@param bars_data chronicles.Dashboard.BarData[]
---@param bar_representation chronicles.BarRepresentation
---@param bar_header_extends_by integer
---@param bar_footer_extends_by integer
---@param max_bar_height integer
---@param bar_width integer
---@param win_width integer
M.set_bars_lines_highlights = function(
  lines,
  highlights,
  bars_data,
  bar_representation,
  bar_header_extends_by,
  bar_footer_extends_by,
  max_bar_height,
  bar_width,
  win_width
)
  local str_sub = require('dev-chronicles.utils.strings').str_sub
  local len_bar_header_rows = #bar_representation.header.realized_rows
  local len_bar_body_rows = #bar_representation.body.realized_rows
  local len_bar_footer_rows = #bar_representation.footer.realized_rows
  local blank_line_chars = vim.split(string.rep(' ', win_width), '')

  for row = max_bar_height, 1, -1 do
    local line_chars = { unpack(blank_line_chars) }
    local hl_bytes_shift = 0

    for _, bar in ipairs(bars_data) do
      if row <= bar.height then
        local offset
        local pos
        local realized_row
        local row_codepoint_counts
        local char_display_widths
        local bar_representation_index

        if bar.current_bar_level == M.BarLevel.Header then
          offset = bar_header_extends_by
          pos = bar.start_col - offset
          bar_representation_index = bar.curr_bar_representation_index
          realized_row = bar_representation.header.realized_rows[bar_representation_index]
          row_codepoint_counts = bar_representation.header.row_codepoint_counts
          char_display_widths = bar_representation.header.char_display_widths

          if bar_representation_index + 1 > len_bar_header_rows then
            bar.current_bar_level = M.BarLevel.Body
            bar.curr_bar_representation_index = 1
          else
            bar.curr_bar_representation_index = bar_representation_index + 1
          end
        elseif bar.current_bar_level == M.BarLevel.Footer or row == len_bar_footer_rows then
          if row == len_bar_footer_rows then
            bar_representation_index = 1
            bar.current_bar_level = M.BarLevel.Footer
          else
            bar_representation_index = bar.curr_bar_representation_index
          end

          offset = bar_footer_extends_by
          pos = bar.start_col - offset
          realized_row = bar_representation.footer.realized_rows[bar_representation_index]
          row_codepoint_counts = bar_representation.footer.row_codepoint_counts
          char_display_widths = bar_representation.footer.char_display_widths
          bar.curr_bar_representation_index = bar.curr_bar_representation_index + 1
        elseif bar.current_bar_level == M.BarLevel.Body then
          offset = 0
          pos = bar.start_col
          bar_representation_index = bar.curr_bar_representation_index
          realized_row = bar_representation.body.realized_rows[bar_representation_index]
          row_codepoint_counts = bar_representation.body.row_codepoint_counts
          char_display_widths = bar_representation.body.char_display_widths
          -- bar_representation_index should start from 0 for this to work, but
          -- we want to calculate the next index, so we just don't add 1 to it, since
          -- these would cancel out.
          bar.curr_bar_representation_index = (bar_representation_index % len_bar_body_rows) + 1
        end

        for i = 1, row_codepoint_counts[bar_representation_index] do
          pos = pos + 1
          local char = str_sub(realized_row, i, i)
          line_chars[pos] = char

          local char_disp_width = char_display_widths[bar_representation_index][i]

          for j = 1, char_disp_width - 1 do
            line_chars[pos + j] = ''
          end
          pos = pos + char_disp_width - 1
        end

        -- TODO: I should precalculate that
        local n_bytes_bar_row_str = #realized_row

        -- bar.start_col does not account for multibyte characters and
        -- highlights operate on bytes, so we use hl_bytes_shift to combat that
        table.insert(highlights, {
          line = #lines + 1,
          col = bar.start_col - offset + hl_bytes_shift,
          end_col = bar.start_col - offset + n_bytes_bar_row_str + hl_bytes_shift,
          hl_group = bar.color,
        })

        -- bar_width equals vim.fn.strdisplaywidth(bar_row_str) for the body
        -- row, enforced in M.construct_bar_string_tbl_representation. If it's
        -- not a body row, then the offset can be non zero, which represents
        -- a bar row being wider than the body row, hence the last term.
        hl_bytes_shift = hl_bytes_shift + n_bytes_bar_row_str - bar_width - (offset * 2)
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
