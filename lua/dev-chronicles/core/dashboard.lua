local M = {}

---@class Stats.ParsedProjectsData
---@field total_time integer
---@field last_worked integer

---@alias Stats.ParsedProjects table<string, Stats.ParsedProjectsData>

---@class Stats
---@field global_time integer
---@field global_time_filtered integer
---@field projects_filtered Projects
---@field projects_filtered_parsed Stats.ParsedProjects
---@field start_date string
---@field end_date string

local colors = {
  'DevChroniclesRed',
  'DevChroniclesBlue',
  'DevChroniclesGreen',
  'DevChroniclesYellow',
  'DevChroniclesMagenta',
  'DevChroniclesCyan',
  'DevChroniclesOrange',
  'DevChroniclesPurple',
}

local function generate_bar(height, color_name)
  local bar_lines = {}
  local patterns = { '/', '\\' }

  for i = 1, height do
    -- Alternate between / and \ for crosshatch effect
    local char = patterns[(i % 2) + 1]
    table.insert(bar_lines, char)
  end

  return bar_lines, color_name
end

---Creates lines and highlights for the dashboard
---@param stats Stats
---@param win_width integer
---@param win_height integer
---@param dashboard_type DashboardType
---@return table, table: Lines, Highlights
M.create_dashboard_content = function(stats, win_width, win_height, dashboard_type)
  local string_utils = require('dev-chronicles.utils.strings')
  local lines = {}
  local highlights = {}

  if next(stats) == nil then
    table.insert(lines, '')
    table.insert(lines, 'No recent projects found (Loser).')
    table.insert(lines, 'Start coding in your tracked directories!')
    return lines, highlights
  end

  local utils = require('dev-chronicles.utils')
  local dashboard_opts = require('dev-chronicles.config').options.dashboard

  -- Reserve space for UI elements
  local header_height = 3
  local footer_height = 3
  local chart_height = win_height - header_height - footer_height
  local chart_width = win_width - 4 -- margins

  -- Header
  local left_header = string.format(
    'Ξ Total Time: %s',
    utils.format_time(stats.global_time_filtered, dashboard_opts.total_time_as_hours_max)
  )
  local right_header = utils.get_time_period_str(stats.start_date, stats.end_date)
  local header_padding = win_width - #left_header - #right_header
  table.insert(lines, left_header .. string.rep(' ', header_padding) .. right_header)
  table.insert(lines, '')
  table.insert(lines, string.rep('─', win_width))

  table.insert(highlights, { line = 1, col = 0, end_col = -1, hl_group = 'DevChroniclesTitle' })

  -- Turn into an array, so that it can be sorted and traversed in order, and calculate max_time
  ---@type table<integer, {id: string, time: integer, last_worked: integer}>
  local arr_projects = {}
  local max_time = 0

  for parsed_project_id, parsed_project_data in pairs(stats.projects_filtered_parsed) do
    if parsed_project_data.total_time > max_time then
      max_time = parsed_project_data.total_time
    end
    table.insert(arr_projects, {
      id = parsed_project_id,
      time = parsed_project_data.total_time,
      last_worked = parsed_project_data.last_worked,
    })
  end

  local correct_dashboard_sorting_opts = (
    dashboard_type == require('dev-chronicles.api').DashboardType.All
    and dashboard_opts.dashboard_all
  ) or dashboard_opts

  if correct_dashboard_sorting_opts.sort then
    local by_last_worked = correct_dashboard_sorting_opts.sort_by_last_worked_not_total_time
    local asc = correct_dashboard_sorting_opts.ascending
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

  -- Calculate bar dimensions
  local bar_spacing = 2
  local max_bar_width =
    math.floor((chart_width - (#arr_projects - 1) * bar_spacing) / #arr_projects)
  -- TODO: possibly cuttoff projects if samller than x to account for project
  -- names that make sense. Then just hard compare the #projects. This is hard
  -- with sorting being togglebale and asceding too
  -- local bar_width = math.min(8, max_bar_width)
  local bar_width = math.min(10, max_bar_width)
  local total_chart_width = #arr_projects * bar_width + (#arr_projects - 1) * bar_spacing
  local chart_start_col = math.floor((win_width - total_chart_width) / 2)

  ---@class BarsData
  ---@field project_name string
  ---@field project_time integer
  ---@field height  integer
  ---@field lines table
  ---@field color string
  ---@field start_col integer
  ---@field width integer
  local bars_data = {}
  for i, project in ipairs(arr_projects) do
    local bar_height = math.max(1, math.floor((project.time / max_time) * (chart_height - 4)))
    local color = colors[((i - 1) % #colors) + 1]
    local bar_lines, bar_color = generate_bar(bar_height, color)

    table.insert(bars_data, {
      project_name = string_utils.get_project_name(project.id),
      project_time = project.time,
      height = bar_height,
      lines = bar_lines,
      color = bar_color,
      start_col = chart_start_col + (i - 1) * (bar_width + bar_spacing),
      width = bar_width,
    })
  end

  -- Add time labels above bars
  local time_line = string.rep(' ', win_width)
  for _, bar in ipairs(bars_data) do
    local time_str = utils.format_time(bar.project_time)
    local label_start = bar.start_col + math.floor((bar.width - #time_str) / 2)
    if label_start >= 0 and label_start + #time_str <= win_width then
      time_line = time_line:sub(1, label_start)
        .. time_str
        .. time_line:sub(label_start + #time_str + 1)
      table.insert(highlights, {
        line = #lines + 1, -- Line stays the same - always the next one
        col = label_start,
        end_col = label_start + #time_str,
        hl_group = 'DevChroniclesTime',
      })
    end
  end
  table.insert(lines, time_line)
  table.insert(lines, '')

  -- Generate bar chart lines
  local max_bar_height = (chart_height - 4)
  -- TODO: Does not seem this is needed if highest bar takes max hight
  -- local max_bar_height = math.max(
  --   1,
  --   math.max(unpack(vim.tbl_map(function(b)
  --     return b.height
  --   end, bars_data)))
  -- )

  for row = max_bar_height, 1, -1 do
    local line = string.rep(' ', win_width)

    for _, bar in ipairs(bars_data) do
      if row <= bar.height then
        local char_idx = bar.height - row + 1
        local char = bar.lines[char_idx] or bar.lines[1] -- or not needed?

        -- Fill the bar width with the character
        for col = 0, bar.width - 1 do
          local pos = bar.start_col + col
          if pos >= 0 and pos < win_width then
            line = line:sub(1, pos) .. char .. line:sub(pos + 2)
          end
        end

        -- Add highlight for this bar segment
        table.insert(highlights, {
          line = #lines + 1,
          col = bar.start_col,
          end_col = bar.start_col + bar.width,
          hl_group = bar.color,
        })
      end
    end

    table.insert(lines, line)
  end

  -- Add baseline
  table.insert(lines, string.rep('─', win_width))
  table.insert(
    highlights,
    { line = #lines, col = 0, end_col = -1, hl_group = 'DevChroniclesLabel' }
  )

  -- Add project names
  local names_line = string.rep(' ', win_width)
  for _, bar in ipairs(bars_data) do
    local name = bar.project_name
    -- Truncate name if too long for bar width
    if #name > bar.width then
      name = name:sub(1, bar.width - 1) .. '.' -- '…'
    end

    local name_start = bar.start_col + math.floor((bar.width - #name) / 2)
    if name_start >= 0 and name_start + #name <= win_width then
      names_line = names_line:sub(1, name_start) .. name .. names_line:sub(name_start + #name + 1)
      table.insert(highlights, {
        line = #lines + 1,
        col = name_start,
        end_col = name_start + #name,
        hl_group = bar.color,
      })
    end
  end
  table.insert(lines, names_line)

  return lines, highlights
end

---Get desired project stats depending on the DashboardType
---@param dashboard_type DashboardType
---@param start? string  Starting month 'MM.YYYY'
---@param end_? string  End month 'MM.YYYY'
---@return Stats
M.get_stats = function(dashboard_type, start, end_)
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return {}
  end

  if dashboard_type == require('dev-chronicles.api').DashboardType.All then
    return {
      global_time = data.global_time,
      global_time_filtered = data.global_time,
      projects_filtered = data.projects,
      projects_filtered_parsed = data.projects,
      start_date = utils.get_month_str(data.tracking_start),
      end_date = utils.get_month_str(),
    }
  end

  local options = require('dev-chronicles.config').options

  if dashboard_type == require('dev-chronicles.api').DashboardType.Default then
    local curr_month = utils.get_month_str()
    start = utils.get_previous_month(curr_month, options.dashboard.n_months_by_default - 1)
    end_ = curr_month
  end

  if not start or not end_ then
    vim.notify('When displaying custom dashboard both start and end_ date should be set')
    return {}
  end

  -- First filter out all the projects that where not worked on during chosen period
  ---@type table<string, ProjectData>
  local filtered_projects = {}

  local start_timestamp = utils.convert_month_str_to_timestamp(start)
  local end_timestamp = utils.convert_month_str_to_timestamp(end_, true)

  if start_timestamp > end_timestamp then
    vim.notify('DevChronicles error: start date cannot be greater than end date')
    return {}
  end

  for project_id, project_data in pairs(data.projects) do
    if project_data.first_worked < end_timestamp and project_data.last_worked > start_timestamp then
      filtered_projects[project_id] = project_data
    end
  end

  if next(filtered_projects) == nil then
    vim.notify('DevChronicles: No project data in the specified period')
    return {}
  end

  -- Collect total time for each project in the chosen time period and
  -- last_worked time from the filtered projects
  ---@type Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0

  -- start_month -> Month before the target month to account for the loop not being inclusive
  local start_month, start_year = utils.extract_month_year(utils.get_previous_month(start))
  local curr_month, curr_year = utils.extract_month_year(end_)

  while not (start_month == curr_month and start_year == curr_year) do
    local curr_date_key = string.format('%02d.%d', curr_month, curr_year)
    for project_id, project_data in pairs(filtered_projects) do
      local month_time = project_data.by_month[curr_date_key]
      if month_time ~= nil then
        if not projects_filtered_parsed[project_id] then
          projects_filtered_parsed[project_id] =
            { total_time = 0, last_worked = project_data.last_worked }
        end
        local filtered_project = projects_filtered_parsed[project_id]
        filtered_project.total_time = filtered_project.total_time + month_time
        global_time_filtered = global_time_filtered + month_time
      end
    end
    curr_month = curr_month - 1
    if curr_month == 0 then
      curr_month = 12
      curr_year = curr_year - 1
    end
  end

  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    projects_filtered = filtered_projects,
    projects_filtered_parsed = projects_filtered_parsed,
    start_date = start,
    end_date = end_,
  }
end

M.get_recent_stats = function(days)
  days = days or 30
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return
  end
  local cutoff_time = utils.get_current_timestamp() - (days * 86400) -- 24 * 60 * 60

  local recent_projects = {}
  for project_id, project_data in pairs(data.projects) do
    if project_data.last_worked >= cutoff_time then
      recent_projects[project_id] = project_data
    end
  end

  return {
    global_time = data.global_time,
    projects = recent_projects,
  }
end

return M
