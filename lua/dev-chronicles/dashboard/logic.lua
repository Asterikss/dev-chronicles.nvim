local M = {}

---Unrolls provided bar representation pattern to match the width of each BarLevel. Upon
---failure, returns the fallback bar representation consisting of `@`. Also returns
---codepoints counts for all the rows and char display width for each character in
---each row.
---@param pattern string[][]
---@param bar_width integer
---@param bar_header_extends_by integer
---@param bar_footer_extends_by integer
---@return chronicles.BarRepresentation
function M.construct_bar_representation(
  pattern,
  bar_width,
  bar_header_extends_by,
  bar_footer_extends_by
)
  local notify = require('dev-chronicles.utils.notify')
  local str_sub = require('dev-chronicles.utils.strings').str_sub
  local bar_representation = {}
  local return_bar_header_extends_by = bar_header_extends_by
  local return_bar_footer_extends_by = bar_footer_extends_by
  local keys = { 'header', 'body', 'footer' }

  for j = 1, 3 do
    local realized_rows = {}
    local row_codepoint_counts = {}
    local char_display_widths = {}
    local width = bar_width

    if j == 1 then
      width = bar_width + (return_bar_header_extends_by * 2)
    elseif j == 3 then
      width = bar_width + (return_bar_footer_extends_by * 2)
    elseif j == 2 and next(pattern[j]) == nil then
      notify.warn(
        'bar_repr BodyLevel (middle one) cannot be empty. Falling back to @ bar representation'
      )
      return M._construct_fallback_bar_representation(bar_width)
    end

    for _, row_chars in ipairs(pattern[j]) do
      local tmp_char_display_widths = {}
      local row_chars_display_width = 0
      local row_chars_codepoints = vim.str_utfindex(row_chars)

      for i = 1, row_chars_codepoints do
        local char = str_sub(row_chars, i, i)
        local char_display_width = vim.fn.strdisplaywidth(char)
        row_chars_display_width = row_chars_display_width + char_display_width
        table.insert(tmp_char_display_widths, char_display_width)
      end

      local n_to_fill_bar_width

      if row_chars_display_width == width then
        table.insert(char_display_widths, tmp_char_display_widths)
        n_to_fill_bar_width = 1
      else
        n_to_fill_bar_width = width / row_chars_display_width

        if n_to_fill_bar_width ~= math.floor(n_to_fill_bar_width) then
          notify.warn(
            'Provided bar_repr row characters in '
              .. keys[j]
              .. ' level: '
              .. row_chars
              .. ' cannot be smoothly expanded to width='
              .. tostring(width)
              .. ' given their display_width='
              .. tostring(row_chars_display_width)
              .. '. Falling back to @ bar representation'
          )
          return M._construct_fallback_bar_representation(bar_width)
        end

        local char_display_widths_entry = {}
        local len_tmp_char_display_widths = #tmp_char_display_widths

        for i = 1, #tmp_char_display_widths * n_to_fill_bar_width do
          char_display_widths_entry[i] =
            tmp_char_display_widths[((i - 1) % len_tmp_char_display_widths) + 1]
        end

        table.insert(char_display_widths, char_display_widths_entry)
      end

      local row = string.rep(row_chars, n_to_fill_bar_width)
      table.insert(realized_rows, row)
      table.insert(row_codepoint_counts, n_to_fill_bar_width * row_chars_codepoints)
    end

    bar_representation[keys[j]] = {
      realized_rows = realized_rows,
      row_codepoint_counts = row_codepoint_counts,
      char_display_widths = char_display_widths,
    }
  end

  -- `bar_rows_codepoints` entries can be deduced by the length of
  -- `bar_rows_chars_disp_width` entries, but that's O(n) and I already
  -- calculate `n_to_fill_bar_width` and `row_chars_codepoint` anyway, so I
  -- will construct a helper array here. The reason why
  -- `bar_rows_chars_disp_width` is needed is for characters that take more
  -- than one column to work. It contains tables for each row, since you can
  -- supply multiple characters to construct a row of the bar, where each
  -- character can have a different display width and a different number of
  -- bytes.
  return bar_representation
end

---@param bar_width integer
---@return chronicles.BarRepresentation
function M._construct_fallback_bar_representation(bar_width)
  local bar_representation = {}
  local char_display_widths_entry = {}
  for i = 1, bar_width do
    char_display_widths_entry[i] = 1
  end
  bar_representation.header = {
    realized_rows = {},
    row_codepoint_counts = {},
    char_display_widths = {},
  }
  bar_representation.body = {
    realized_rows = { string.rep('@', bar_width) },
    row_codepoint_counts = { bar_width },
    char_display_widths = { char_display_widths_entry },
  }
  bar_representation.footer = {
    realized_rows = {},
    row_codepoint_counts = {},
    char_display_widths = {},
  }
  return bar_representation
end

---Calculates number of projects to keep and the chart starting column
---@param bar_width integer
---@param bar_spacing integer
---@param max_chart_width integer
---@param n_projects integer
---@param win_width integer
---@return integer, integer: n_projects_to_keep, chart_start_col
function M.calc_chart_stats(bar_width, bar_spacing, max_chart_width, n_projects, win_width)
  if n_projects < 1 then
    return 0, -1
  end
  -- total_width = k_bars * bar_width + (k_bars - 1) * bar_spacing
  -- k_bars * bar_width + (k_bars - 1) * bar_spacing <= max_chart_width
  -- k_bars * (bar_width + bar_spacing) - bar_spacing <= max_chart_width
  local max_n_bars = math.floor((max_chart_width + bar_spacing) / (bar_width + bar_spacing))
  local n_projects_to_keep = math.min(n_projects, max_n_bars)

  local chart_width = (n_projects_to_keep * bar_width) + ((n_projects_to_keep - 1) * bar_spacing)
  local chart_start_col = math.floor((win_width - chart_width) / 2)

  return n_projects_to_keep, chart_start_col
end

---@param arr_projects chronicles.Dashboard.FinalProjectData[]
---@param len_arr_projects integer
---@param n_projects_to_keep integer
---@param max_project_time integer
---@param sorting chronicles.Options.Dashboard.Sorting
---@return chronicles.Dashboard.FinalProjectData[], integer, integer: arr_projects, len_arr_projects, max_project_time
function M.sort_and_cut_off_projects(
  arr_projects,
  len_arr_projects,
  n_projects_to_keep,
  max_project_time,
  sorting
)
  if sorting.enable then
    table.sort(arr_projects, function(a, b)
      if sorting.sort_by_last_worked_not_total_time then
        if sorting.ascending then
          return a.last_worked < b.last_worked
        else
          return a.last_worked > b.last_worked
        end
      else
        if sorting.ascending then
          return a.total_time < b.total_time
        else
          return a.total_time > b.total_time
        end
      end
    end)
  end

  if n_projects_to_keep == len_arr_projects then
    return arr_projects, len_arr_projects, max_project_time
  end

  local first, last
  if sorting.ascending then
    first = math.max(1, len_arr_projects - n_projects_to_keep + 1)
    last = len_arr_projects
  else
    first = 1
    last = math.min(n_projects_to_keep, len_arr_projects)
  end

  ---@type chronicles.Dashboard.FinalProjectData[]
  local arr_projects_filtered, len_arr_projects_filtered = {}, 0
  local new_max_project_time = 0

  for i = first, last do
    local project_data = arr_projects[i]
    len_arr_projects_filtered = len_arr_projects_filtered + 1
    arr_projects_filtered[len_arr_projects_filtered] = project_data
    new_max_project_time = math.max(new_max_project_time, project_data.total_time)
  end

  return arr_projects_filtered, len_arr_projects_filtered, new_max_project_time
end

---@param arr_projects chronicles.Dashboard.FinalProjectData[]
---@param project_name_tbls_arr string[][]
---@param max_time integer
---@param max_bar_height integer
---@param chart_start_col integer
---@param bar_width integer
---@param bar_spacing integer
---@param random_bars_coloring boolean
---@param projects_sorted_ascending boolean
---@param bar_header_realized_rows_tbl string[]
---@return chronicles.Dashboard.BarData[], table<string, string>
function M.create_bars_data(
  arr_projects,
  project_name_tbls_arr,
  max_time,
  max_bar_height,
  chart_start_col,
  bar_width,
  bar_spacing,
  random_bars_coloring,
  projects_sorted_ascending,
  bar_header_realized_rows_tbl
)
  local BarLevel = require('dev-chronicles.core.enums').BarLevel
  local get_project_highlight = require('dev-chronicles.core.colors').closure_get_project_highlight(
    random_bars_coloring,
    projects_sorted_ascending,
    #arr_projects
  )

  ---@type chronicles.Dashboard.BarData[]
  local bars_data = {}
  ---@type table<string, string>
  local project_id_to_highlight = {}

  for i, project in ipairs(arr_projects) do
    local bar_height = math.max(1, math.floor((project.total_time / max_time) * max_bar_height))
    local highlight = get_project_highlight(project.color)

    local project_id = project.project_id
    project_id_to_highlight[project_id] = highlight

    bars_data[i] = {
      project_name_tbl = project_name_tbls_arr[i],
      project_time = project.total_time,
      height = bar_height,
      color = highlight,
      start_col = chart_start_col + (i - 1) * (bar_width + bar_spacing),
      width = bar_width,
      current_bar_level = (next(bar_header_realized_rows_tbl) ~= nil) and BarLevel.Header
        or BarLevel.Body,
      curr_bar_representation_index = 1,
      global_project_time = project.global_time,
    }
  end

  return bars_data, project_id_to_highlight
end

---@param final_project_data_arr chronicles.Dashboard.FinalProjectData[]
---@param min_proj_time_to_display_proj integer
---@return chronicles.Dashboard.FinalProjectData[]
function M.filter_by_min_time(final_project_data_arr, min_proj_time_to_display_proj)
  local out = {}
  local len_out = 0

  for _, project_data in ipairs(final_project_data_arr) do
    if project_data.total_time >= min_proj_time_to_display_proj then
      len_out = len_out + 1
      out[len_out] = project_data
    end
  end

  return out
end

---@param initial_max_bar_height integer
---@param thresholds any -- TODO: consolidate thresholds
---@param max_time integer
---@return integer
function M.calc_max_bar_height(initial_max_bar_height, thresholds, max_time)
  for i, threshold in ipairs(thresholds) do
    if max_time < threshold * 3600 then
      return math.floor((i / (#thresholds + 1)) * initial_max_bar_height)
    end
  end
  return initial_max_bar_height
end

---@param arr_projects chronicles.Dashboard.FinalProjectData[]
---@param max_footer_height integer
---@param bar_width integer
---@param let_proj_names_extend_bars_by_one boolean
---@return string[][], integer
function M.get_project_name_tbls_arr(
  arr_projects,
  max_footer_height,
  bar_width,
  let_proj_names_extend_bars_by_one
)
  local string_utils = require('dev-chronicles.utils.strings')

  ---@type string[][]
  local project_name_tbls_arr = {}
  local footer_height = 0

  for i, project_data in ipairs(arr_projects) do
    local project_name_tbl = string_utils.format_project_name(
      string_utils.get_project_name(project_data.project_id),
      bar_width + (let_proj_names_extend_bars_by_one and 2 or 0),
      max_footer_height
    )

    project_name_tbls_arr[i] = project_name_tbl
    footer_height = math.max(footer_height, #project_name_tbl)
  end

  return project_name_tbls_arr, footer_height
end

return M
