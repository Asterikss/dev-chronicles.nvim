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
---@param sort boolean
---@param by_last_worked boolean
---@param asc boolean
---@return chronicles.Dashboard.FinalProjectData[], integer
function M.sort_and_cutoff_projects(
  arr_projects,
  len_arr_projects,
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
          return a.total_time < b.total_time
        else
          return a.total_time > b.total_time
        end
      end
    end)
  end

  if n_projects_to_keep == len_arr_projects then
    return arr_projects, len_arr_projects
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

  return arr_projects_filtered, #arr_projects_filtered
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
---@param differentiate_projects_by_folder_not_path boolean
---@return chronicles.Dashboard.BarData[], integer, table<string, string>
function M.create_bars_data(
  arr_projects,
  max_time,
  max_bar_height,
  chart_start_col,
  bar_width,
  bar_spacing,
  let_proj_names_extend_bars_by_one,
  random_bars_coloring,
  projects_sorted_ascending,
  bar_header_realized_rows_tbl,
  differentiate_projects_by_folder_not_path
)
  local string_utils = require('dev-chronicles.utils.strings')
  local BarLevel = require('dev-chronicles.core.enums').BarLevel
  local shuffle = require('dev-chronicles.utils').shuffle

  ---@type chronicles.Dashboard.BarData[]
  local bars_data = {}
  ---@type table<string, string>
  local project_id_to_color = {}
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
    local bar_height = math.max(1, math.floor((project.total_time / max_time) * max_bar_height))

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

    local project_id = project.id
    project_id_to_color[project_id] = color

    local project_name = differentiate_projects_by_folder_not_path and project_id
      or string_utils.get_project_name(project_id)
    local project_name_tbl = string_utils.format_project_name(
      project_name,
      bar_width + (let_proj_names_extend_bars_by_one and 2 or 0)
    )
    max_lines_proj_names = math.max(max_lines_proj_names, #project_name_tbl)

    table.insert(bars_data, {
      project_name_tbl = project_name_tbl,
      project_time = project.total_time,
      height = bar_height,
      color = color,
      start_col = chart_start_col + (i - 1) * (bar_width + bar_spacing),
      width = bar_width,
      current_bar_level = (next(bar_header_realized_rows_tbl) ~= nil) and BarLevel.Header
        or BarLevel.Body,
      curr_bar_representation_index = 1,
      global_project_time = project.global_time,
    })
  end

  return bars_data, max_lines_proj_names, project_id_to_color
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

function M.calc_max_bar_height(initial_max_bar_height, thresholds, max_time)
  for i, threshold in ipairs(thresholds) do
    if max_time < threshold * 3600 then
      return math.floor((i / (#thresholds + 1)) * initial_max_bar_height)
    end
  end
  return initial_max_bar_height
end

return M
