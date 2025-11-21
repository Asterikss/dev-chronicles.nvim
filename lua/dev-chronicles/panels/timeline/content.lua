local M = {}

local DefaultColors = require('dev-chronicles.core.enums').DefaultColors
local format_time = require('dev-chronicles.core.time').format_time

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

  lines[len_lines + 1] = header1
  lines[len_lines + 2] = header2
  lines[len_lines + 3] = ''

  local left_header_bytes = #left_header
  table.insert(highlights, {
    line = len_lines + 1,
    col = 0,
    end_col = left_header_bytes,
    hl_group = DefaultColors.DevChroniclesAccent,
  })

  local header1_hl_rolling_col = left_header_bytes
    + min_project_str_pad_ammount
    + extra_pad_left
    + extra_pad_left_header1

  for index, entry_bytes in ipairs(header1_proj_entries_bytes) do
    table.insert(highlights, {
      line = len_lines + 1,
      col = header1_hl_rolling_col,
      end_col = header1_hl_rolling_col + entry_bytes,
      hl_group = header1_proj_entries_highlights[index],
    })
    header1_hl_rolling_col = header1_hl_rolling_col + entry_bytes + spacing_between_projects
  end

  header1_hl_rolling_col = header1_hl_rolling_col
    + extra_pad_right_header1
    + extra_pad_right
    + min_project_str_pad_ammount

  table.insert(highlights, {
    line = len_lines + 1,
    col = header1_hl_rolling_col,
    end_col = -1,
    hl_group = DefaultColors.DevChroniclesAccent,
  })

  local left_decorator_bytes = #decorator_left
  table.insert(highlights, {
    line = len_lines + 2,
    col = 0,
    end_col = left_decorator_bytes,
    hl_group = DefaultColors.DevChroniclesAccent,
  })

  local header2_hl_rolling_col = left_decorator_bytes
    + min_project_str_pad_ammount
    + extra_pad_left
    + extra_pad_left_header2

  for index, entry_bytes in ipairs(header2_proj_entries_bytes) do
    table.insert(highlights, {
      line = len_lines + 2,
      col = header2_hl_rolling_col,
      end_col = header2_hl_rolling_col + entry_bytes,
      hl_group = header2_proj_entries_highlights[index],
    })
    header2_hl_rolling_col = header2_hl_rolling_col + entry_bytes + spacing_between_projects
  end

  header2_hl_rolling_col = header2_hl_rolling_col
    + extra_pad_right_header2
    + extra_pad_right
    + min_project_str_pad_ammount

  table.insert(highlights, {
    line = len_lines + 2,
    col = header2_hl_rolling_col,
    end_col = -1,
    hl_group = DefaultColors.DevChroniclesAccent,
  })

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

return M
