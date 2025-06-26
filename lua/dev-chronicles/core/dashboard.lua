local M = {}

M.DashboardType = {
  Default = 1,
  Custom = 2,
  All = 3,
}

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

M.setup_highlights = function()
  local highlights = {
    DevChroniclesRed = { fg = '#ff6b6b', bold = true },
    DevChroniclesBlue = { fg = '#4ecdc4', bold = true },
    DevChroniclesGreen = { fg = '#95e1d3', bold = true },
    DevChroniclesYellow = { fg = '#f9ca24', bold = true },
    DevChroniclesMagenta = { fg = '#f0932b', bold = true },
    DevChroniclesCyan = { fg = '#6c5ce7', bold = true },
    DevChroniclesOrange = { fg = '#ff7675', bold = true },
    DevChroniclesPurple = { fg = '#a29bfe', bold = true },
    DevChroniclesTitle = { fg = '#ffffff', bold = true },
    DevChroniclesLabel = { fg = '#b2bec3', bold = false },
    DevChroniclesTime = { fg = '#dddddd', bold = true },
  }

  for name, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

local function get_project_name(project_id)
  return project_id:match('([^/]+)/?$') or project_id
end

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

M.create_dashboard_content = function(stats, win_width, win_height)
  local format_time = require('dev-chronicles.utils').format_time
  local lines = {}
  local highlights = {}

  -- Reserve space for UI elements
  local header_height = 3
  local footer_height = 3
  local chart_height = win_height - header_height - footer_height
  local chart_width = win_width - 4 -- margins

  -- Header
  table.insert(lines, string.format('Total Time: %s', format_time(stats.global_time)))
  table.insert(lines, '')
  table.insert(lines, string.rep('─', win_width))

  table.insert(highlights, { line = 1, col = 0, end_col = -1, hl_group = 'DevChroniclesTitle' })

  -- Prepare project data
  local projects = {}
  for project_id, project_data in pairs(stats.projects) do
    table.insert(projects, {
      id = project_id,
      name = get_project_name(project_id),
      time = project_data.total_time,
      data = project_data,
    })
  end

  -- Sort by time (descending)
  table.sort(projects, function(a, b)
    return a.time > b.time
  end)

  if #projects == 0 then
    table.insert(lines, '')
    table.insert(lines, 'No recent projects found.')
    table.insert(lines, 'Start coding in your tracked directories!')
    return lines, highlights
  end

  -- Calculate bar dimensions
  local max_time = projects[1].time
  local bar_spacing = 2
  local max_bar_width = math.floor((chart_width - (#projects - 1) * bar_spacing) / #projects)
  local bar_width = math.min(8, math.max(3, max_bar_width))
  local total_chart_width = #projects * bar_width + (#projects - 1) * bar_spacing
  local chart_start_col = math.floor((win_width - total_chart_width) / 2)

  -- Create bars data
  local bars_data = {}
  for i, project in ipairs(projects) do
    local bar_height = math.max(1, math.floor((project.time / max_time) * (chart_height - 4)))
    local color = colors[((i - 1) % #colors) + 1]
    local bar_lines, bar_color = generate_bar(bar_height, color)

    table.insert(bars_data, {
      project = project,
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
    local time_str = format_time(bar.project.time)
    local label_start = bar.start_col + math.floor((bar.width - #time_str) / 2)
    if label_start >= 0 and label_start + #time_str <= win_width then
      time_line = time_line:sub(1, label_start) .. time_str .. time_line:sub(label_start + #time_str + 1)
      table.insert(highlights, {
        line = #lines + 1,
        col = label_start,
        end_col = label_start + #time_str,
        hl_group = 'DevChroniclesTime',
      })
    end
  end
  table.insert(lines, time_line)
  table.insert(lines, '')

  -- Generate bar chart lines
  local max_bar_height = math.max(
    1,
    math.max(unpack(vim.tbl_map(function(b)
      return b.height
    end, bars_data)))
  )

  for row = max_bar_height, 1, -1 do
    local line = string.rep(' ', win_width)

    for _, bar in ipairs(bars_data) do
      if row <= bar.height then
        local char_idx = bar.height - row + 1
        local char = bar.lines[char_idx] or bar.lines[1]

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
  table.insert(highlights, { line = #lines, col = 0, end_col = -1, hl_group = 'DevChroniclesLabel' })

  -- Add project names
  local names_line = string.rep(' ', win_width)
  for _, bar in ipairs(bars_data) do
    local name = bar.project.name
    -- Truncate name if too long for bar width
    if #name > bar.width then
      name = name:sub(1, bar.width - 1) .. '…'
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

---Get the filtered project stats depending on the DashboardType
---@param dashboard_type DashboardType Default | Custom | All
---@param start? string  Start month
---@param end_? string  End month
M.get_stats = function(dashboard_type, start, end_)
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return
  end

  if dashboard_type == M.DashboardType.All then
    return data
  end

  local options = require('dev-chronicles.config').options

  if dashboard_type == M.DashboardType.Default then
    local curr_month = utils.get_current_month()
    start = utils.get_previous_month(curr_month, options.dashboard.n_months_by_default - 1)
    end_ = curr_month
  end

  if not start or not end_ then
    vim.notify('When displaying custom dashboard both start and end_ date should be set')
    return
  end

  -- First filter out all the projects where not worked on during set period
  ---@type table<string, ProjectData>
  local filtered_projects = {}

  local start_timestamp = utils.convert_month_str_to_timestamp(start)
  local end_timestamp = utils.convert_month_str_to_timestamp(end_, true)

  if start_timestamp > end_timestamp then
    vim.notify('DevChronicles error: start date cannot be greater than end date')
    return
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

  -- Collect total time for each project in the chosen time period from the filtered projects
  ---@type table<string, integer>
  local projects_total_time = {}

  local start_month, start_year = utils.extract_month_year(start)
  local curr_month, curr_year = utils.extract_month_year(end_)

  while not (start_month == curr_month and start_year == curr_year) do
    local curr_date_key = string.format('%02d.%d', curr_month, curr_year)
    for project_id, project_data in pairs(filtered_projects) do
      local month_time = project_data.by_month[curr_date_key]
      if month_time ~= nil then
        projects_total_time[project_id] = (projects_total_time[project_id] or 0) + month_time
      end
    end
    curr_month = curr_month - 1
    if curr_month == 0 then
      curr_month = 12
      curr_year = curr_year - 1
    end
  end

  local curr_date_key = string.format('%02d.%d', curr_month, curr_year)
  for project_id, project_data in pairs(filtered_projects) do
    local month_time = project_data.by_month[curr_date_key]
    if month_time ~= nil then
      projects_total_time[project_id] = (projects_total_time[project_id] or 0) + month_time
    end
  end

  vim.notify(vim.inspect(filtered_projects))
  vim.notify(vim.inspect(projects_total_time))

  return {
    global_time = data.global_time, -- TODO: possibly only the filtered ones, or both
    projects = filtered_projects,
    projects_total_time = projects_total_time,
  }
end

M.get_recent_stats = function(days)
  days = days or 30
  local utils = require('dev-chronicles.utils')
  local data = utils.load_data()
  if not data then
    return
  end
  local cutoff_time = utils.current_timestamp() - (days * 86400) -- 24 * 60 * 60

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
