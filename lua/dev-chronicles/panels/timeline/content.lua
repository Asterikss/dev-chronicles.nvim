local M = {}

local DefaultColors = require('dev-chronicles.core.enums').DefaultColors
local format_time = require('dev-chronicles.core.time').format_time

---Adds a 4 line header
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param header_timeline_type_opts chronicles.Options.Timeline.Header
---@param win_width integer
---@param curr_session_time? integer
---@param len_lines? integer
---@return integer: len_lines
function M.set_header_lines_hl(
  lines,
  highlights,
  timeline_data,
  header_timeline_type_opts,
  win_width,
  curr_session_time,
  len_lines
)
  len_lines = len_lines or #lines

  local total_time_opts = header_timeline_type_opts.total_time
  local left_header = '│ '
    .. total_time_opts.format_str:format(
      format_time(
        timeline_data.total_period_time,
        total_time_opts.as_hours_max,
        total_time_opts.as_hours_min,
        total_time_opts.round_hours_ge_x
      )
    )

  if
    header_timeline_type_opts.show_current_session_time
    and curr_session_time
    and timeline_data.does_include_curr_date
  then
    left_header = left_header .. ' (' .. format_time(curr_session_time, true, false) .. ') │'
  else
    left_header = left_header .. ' │'
  end

  local right_header = '│ ' .. timeline_data.time_period_str .. ' │'

  local left_header_disp_width = vim.fn.strdisplaywidth(left_header)
  local right_header_disp_width = vim.fn.strdisplaywidth(right_header)

  local decorator_left = '╰' .. string.rep('─', left_header_disp_width - 2) .. '╯'
  local decorator_right = '╰' .. string.rep('─', right_header_disp_width - 2) .. '╯'

  local project_prefix = header_timeline_type_opts.project_prefix
  local project_prefix_bytes = #project_prefix
  local project_prefix_disp_width = vim.fn.strdisplaywidth(project_prefix)

  local min_project_str_pad_ammount = 1
  local spacing_between_projects = 1

  local extra_pad_left = math.max(0, right_header_disp_width - left_header_disp_width)
  local extra_pad_right = math.max(0, left_header_disp_width - right_header_disp_width)

  local max_proj_names_disp_width = math.min(
    (win_width - (min_project_str_pad_ammount * 2)) - 2 * left_header_disp_width,
    (win_width - (min_project_str_pad_ammount * 2)) - 2 * right_header_disp_width
  )

  if max_proj_names_disp_width <= 0 then
    lines[len_lines + 1] = ''
    lines[len_lines + 2] = ''
    lines[len_lines + 3] = ''
    len_lines = len_lines + 3
    len_lines = require('dev-chronicles.dashboard.content').set_hline_lines_hl(
      lines,
      highlights,
      win_width,
      '─',
      DefaultColors.DevChroniclesAccent,
      len_lines
    )
    return len_lines
  end

  local header1_projects_list = {}
  local len_header1_projects_list_str = 0
  local header1_proj_entries_bytes = {}
  local header1_proj_entries_highlights = {}

  local header2_projects_list = {}
  local len_header2_projects_list_str = 0
  local header2_proj_entries_bytes = {}
  local header2_proj_entries_highlights = {}

  for project_id, highlight in pairs(timeline_data.project_id_to_highlight) do
    local entry_disp_width = vim.fn.strdisplaywidth(project_id) + project_prefix_disp_width
    local header1_entry_disp_width = entry_disp_width
      + (len_header1_projects_list_str > 0 and spacing_between_projects or 0)

    if len_header1_projects_list_str + header1_entry_disp_width <= max_proj_names_disp_width then
      len_header1_projects_list_str = len_header1_projects_list_str + header1_entry_disp_width
      table.insert(header1_projects_list, project_prefix .. project_id)
      table.insert(header1_proj_entries_bytes, #project_id + project_prefix_bytes)
      table.insert(header1_proj_entries_highlights, highlight)
    else
      local header2_entry_disp_width = entry_disp_width
        + (len_header2_projects_list_str > 0 and spacing_between_projects or 0)

      if len_header2_projects_list_str + header2_entry_disp_width <= max_proj_names_disp_width then
        len_header2_projects_list_str = len_header2_projects_list_str + header2_entry_disp_width
        table.insert(header2_projects_list, project_prefix .. project_id)
        table.insert(header2_proj_entries_bytes, #project_id + project_prefix_bytes)
        table.insert(header2_proj_entries_highlights, highlight)
      end
    end
  end

  local header1_projects_list_str =
    table.concat(header1_projects_list, (' '):rep(spacing_between_projects))
  local header2_projects_list_str =
    table.concat(header2_projects_list, (' '):rep(spacing_between_projects))

  local function calculate_extra_padding(total_width, content_width)
    local extra = total_width - content_width
    if extra <= 0 then
      return 0, 0
    end
    local right = math.floor(extra / 2)
    local left = extra - right -- Left gets any odd remainder
    return left, right
  end

  local extra_pad_left_header1, extra_pad_right_header1 =
    calculate_extra_padding(max_proj_names_disp_width, len_header1_projects_list_str)

  local extra_pad_left_header2, extra_pad_right_header2 =
    calculate_extra_padding(max_proj_names_disp_width, len_header2_projects_list_str)

  local header1 = left_header
    .. (' '):rep(min_project_str_pad_ammount)
    .. (' '):rep(extra_pad_left)
    .. (' '):rep(extra_pad_left_header1)
    .. header1_projects_list_str
    .. (' '):rep(extra_pad_right_header1)
    .. (' '):rep(extra_pad_right)
    .. (' '):rep(min_project_str_pad_ammount)
    .. right_header
  local header2 = decorator_left
    .. (' '):rep(min_project_str_pad_ammount)
    .. (' '):rep(extra_pad_left)
    .. (' '):rep(extra_pad_left_header2)
    .. header2_projects_list_str
    .. (' '):rep(extra_pad_right_header2)
    .. (' '):rep(extra_pad_right)
    .. (' '):rep(min_project_str_pad_ammount)
    .. decorator_right

  local function apply_header_highlights(
    line_num,
    left_header_bytes,
    proj_entries_bytes,
    proj_entries_highlights,
    extra_pad_left_side,
    extra_pad_right_side
  )
    table.insert(highlights, {
      line = line_num,
      col = 0,
      end_col = left_header_bytes,
      hl_group = DefaultColors.DevChroniclesAccent,
    })

    local rolling_col = left_header_bytes
      + min_project_str_pad_ammount
      + extra_pad_left
      + extra_pad_left_side

    for index, entry_bytes in ipairs(proj_entries_bytes) do
      table.insert(highlights, {
        line = line_num,
        col = rolling_col,
        end_col = rolling_col + entry_bytes,
        hl_group = proj_entries_highlights[index],
      })
      rolling_col = rolling_col + entry_bytes + spacing_between_projects
    end

    rolling_col = rolling_col + extra_pad_right_side + extra_pad_right + min_project_str_pad_ammount

    table.insert(highlights, {
      line = line_num,
      col = rolling_col,
      end_col = -1,
      hl_group = DefaultColors.DevChroniclesAccent,
    })
  end

  len_lines = len_lines + 1
  lines[len_lines] = header1
  apply_header_highlights(
    len_lines,
    #left_header,
    header1_proj_entries_bytes,
    header1_proj_entries_highlights,
    extra_pad_left_header1,
    extra_pad_right_header1
  )

  len_lines = len_lines + 1
  lines[len_lines] = header2
  apply_header_highlights(
    len_lines,
    #decorator_left,
    header2_proj_entries_bytes,
    header2_proj_entries_highlights,
    extra_pad_left_header2,
    extra_pad_right_header2
  )

  len_lines = len_lines + 1
  lines[len_lines] = ''

  len_lines = require('dev-chronicles.dashboard.content').set_hline_lines_hl(
    lines,
    highlights,
    win_width,
    '─',
    DefaultColors.DevChroniclesAccent,
    len_lines
  )

  return len_lines
end

---Adds 2 lines.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param bar_spacing integer
---@param win_width integer
---@param chart_start_col integer
---@param segment_total_time_opts chronicles.Options.Timeline.Section.SegmentTotalTime
---@param len_lines? integer
function M.set_time_labels_above_bars_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  bar_spacing,
  win_width,
  chart_start_col,
  segment_total_time_opts,
  len_lines
)
  -- Helper function to place a formatted time string onto a character array.
  ---@param target_line string[]
  ---@param time_to_format integer
  ---@param bar_start_col integer
  ---@param bar_widthh integer
  ---@param highlights_insert_positon integer
  ---@param color? string
  ---@param as_hours_max boolean
  ---@param as_hours_min boolean
  ---@param round_hours_ge_x? integer
  local function place_label(
    target_line,
    time_to_format,
    bar_start_col,
    bar_widthh,
    highlights_insert_positon,
    color,
    as_hours_max,
    as_hours_min,
    round_hours_ge_x
  )
    local time_str = format_time(time_to_format, as_hours_max, as_hours_min, round_hours_ge_x)
    local len_time_str = #time_str -- bytes are fine here
    local label_start = bar_start_col + math.floor((bar_widthh - len_time_str) / 2)

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

  len_lines = (len_lines or #lines) + 1
  local time_labels_row = vim.split(string.rep(' ', win_width), '')

  for index, segment_data in ipairs(timeline_data.segments) do
    place_label(
      time_labels_row,
      segment_data.total_segment_time,
      chart_start_col + (index - 1) * (bar_width + bar_spacing),
      bar_width,
      len_lines,
      DefaultColors.DevChroniclesAccent,
      segment_total_time_opts.as_hours_max,
      segment_total_time_opts.as_hours_min,
      segment_total_time_opts.round_hours_ge_x
    )
  end

  lines[len_lines] = table.concat(time_labels_row)
  len_lines = len_lines + 1
  lines[len_lines] = ''

  return len_lines
end

end

return M
