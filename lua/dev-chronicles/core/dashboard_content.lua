local M = {}

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

return M
