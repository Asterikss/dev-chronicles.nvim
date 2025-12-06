local M = {}

local DefaultColors = require('dev-chronicles.core.enums').DefaultColors
local strings = require('dev-chronicles.utils.strings')
local format_time = require('dev-chronicles.core.time').format_time
local get_or_create_hex_highlight =
  require('dev-chronicles.core.colors').get_or_create_hex_highlight

---Adds 4 entries to the lines table.
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

    local len_proj_entries_bytes = #proj_entries_bytes
    for index, entry_bytes in ipairs(proj_entries_bytes) do
      table.insert(highlights, {
        line = line_num,
        col = rolling_col,
        end_col = rolling_col + entry_bytes,
        hl_group = proj_entries_highlights[index],
      })

      rolling_col = rolling_col + entry_bytes
      if index < len_proj_entries_bytes then
        rolling_col = rolling_col + spacing_between_projects
      end
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

---Adds 2 entries to the lines table.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param bar_spacing integer
---@param win_width integer
---@param chart_start_col integer
---@param segment_time_labels_opts chronicles.Options.Timeline.Section.SegmentTimeLabels
---@param len_lines? integer
function M.set_time_labels_above_bars_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  bar_spacing,
  win_width,
  chart_start_col,
  segment_time_labels_opts,
  len_lines
)
  len_lines = (len_lines or #lines) + 1
  local time_labels_row_arr = vim.split(string.rep(' ', win_width), '')
  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local hide_when_empty = segment_time_labels_opts.hide_when_empty
  local as_hours_max = segment_time_labels_opts.as_hours_max
  local as_hours_min = segment_time_labels_opts.as_hours_min
  local round_hours_ge_x = segment_time_labels_opts.round_hours_ge_x
  local color_like_top_segment_project = segment_time_labels_opts.color_like_top_segment_project
  local orig_highlight = segment_time_labels_opts.color
      and get_or_create_hex_highlight(segment_time_labels_opts.color)
    or DefaultColors.DevChroniclesAccent
  local highlight

  for index, segment_data in ipairs(timeline_data.segments) do
    local total_segment_time = segment_data.total_segment_time

    if not hide_when_empty or total_segment_time > 0 then
      if color_like_top_segment_project then
        local project_shares = segment_data.project_shares
        local len_project_shares = #project_shares
        if len_project_shares > 0 then
          highlight = project_id_to_highlight[project_shares[len_project_shares].project_id]
        else
          highlight = orig_highlight
        end
      end

      strings.place_label_simple(
        time_labels_row_arr,
        format_time(total_segment_time, as_hours_max, as_hours_min, round_hours_ge_x),
        chart_start_col + (index - 1) * (bar_width + bar_spacing),
        bar_width,
        highlights,
        len_lines,
        highlight
      )
    end
  end

  lines[len_lines] = table.concat(time_labels_row_arr)
  len_lines = len_lines + 1
  lines[len_lines] = ''

  return len_lines
end


---Adds 1 line
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param bar_spacing integer
---@param win_width integer
---@param chart_start_col integer
---@param numeric_label_opts chronicles.Options.Timeline.Section.SegmentNumericLabels
---@param len_lines? integer
---@return integer: len_lines
function M.set_numeric_labels_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  bar_spacing,
  win_width,
  chart_start_col,
  numeric_label_opts,
  len_lines
)
  len_lines = (len_lines or #lines) + 1
  local labels_row_arr = vim.split(string.rep(' ', win_width), '')
  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local hide_when_empty = numeric_label_opts.hide_when_empty
  local color_like_top_segment_project = numeric_label_opts.color_like_top_segment_project
  local initial_highlight = numeric_label_opts.color
      and get_or_create_hex_highlight(numeric_label_opts.color)
    or DefaultColors.DevChroniclesAccent
  local highlight = initial_highlight

  for index, segment_data in ipairs(timeline_data.segments) do
    if not hide_when_empty or segment_data.total_segment_time > 0 then
      if color_like_top_segment_project then
        local project_shares = segment_data.project_shares
        local len_project_shares = #project_shares
        if len_project_shares > 0 then
          highlight = project_id_to_highlight[project_shares[len_project_shares].project_id]
        else
          highlight = initial_highlight
        end
      end

      local date_label = segment_data.day or segment_data.month or segment_data.year
      strings.place_label_simple(
        labels_row_arr,
        date_label,
        chart_start_col + (index - 1) * (bar_width + bar_spacing),
        bar_width,
        highlights,
        len_lines,
        highlight
      )
    end
  end

  lines[len_lines] = table.concat(labels_row_arr)

  return len_lines
end

---Adds 1 entry to the lines table.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param bar_spacing integer
---@param win_width integer
---@param chart_start_col integer
---@param abbr_label_opts chronicles.Options.Timeline.Section.SegmentAbbrLabels
---@param len_lines? integer
---@return integer: len_lines
function M.set_abbr_labels_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  bar_spacing,
  win_width,
  chart_start_col,
  abbr_label_opts,
  len_lines
)
  len_lines = (len_lines or #lines) + 1
  local abbr_row_arr = vim.split(string.rep(' ', win_width), '')
  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local hide_when_empty = abbr_label_opts.hide_when_empty
  local color_like_top_segment_project = abbr_label_opts.color_like_top_segment_project
  local initial_highlight = abbr_label_opts.color
      and get_or_create_hex_highlight(abbr_label_opts.color)
    or DefaultColors.DevChroniclesAccent
  local highlight = initial_highlight
  local hl_bytes_shift = 0

  for index, segment_data in ipairs(timeline_data.segments) do
    if not hide_when_empty or segment_data.total_segment_time > 0 then
      if color_like_top_segment_project then
        local project_shares = segment_data.project_shares
        local len_project_shares = #project_shares
        if len_project_shares > 0 then
          highlight = project_id_to_highlight[project_shares[len_project_shares].project_id]
        else
          highlight = initial_highlight
        end
      end

      local additional_hl_bytes_shift = strings.place_label(
        abbr_row_arr,
        segment_data.date_abbr,
        chart_start_col + (index - 1) * (bar_width + bar_spacing),
        bar_width,
        highlights,
        len_lines,
        highlight,
        hl_bytes_shift
      )
      hl_bytes_shift = hl_bytes_shift + additional_hl_bytes_shift
    end
  end

  lines[len_lines] = table.concat(abbr_row_arr)

  return len_lines
end

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param win_width integer
---@param win_height integer
---@param header_timeline_type_opts chronicles.Options.Timeline.Header
---@return string[], chronicles.Highlight[]
function M.handle_no_segments_lines_hl(
  lines,
  highlights,
  timeline_data,
  win_width,
  win_height,
  header_timeline_type_opts
)
  M.set_header_lines_hl(lines, highlights, timeline_data, header_timeline_type_opts, win_width, nil)

  require('dev-chronicles.utils').set_no_data_mess_lines_hl(
    lines,
    highlights,
    win_width,
    win_height
  )
  return lines, highlights
end

return M
