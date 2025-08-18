local M = {}

-- TODO: return type
---@param data chronicles.ChroniclesData
---@param canonical_month_str string
---@param canonical_today_str string
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
M.get_dashboard_data_all = function(
  data,
  canonical_month_str,
  canonical_today_str,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str
)
  local time = require('dev-chronicles.core.time')

  return {
    global_time = data.global_time,
    global_time_filtered = data.global_time,
    projects_filtered_parsed = next(data.projects) ~= nil and data.projects,
    time_period_str = time.get_time_period_str_months(
      time.get_month_str(data.tracking_start),
      time.get_month_str(),
      canonical_month_str,
      canonical_today_str,
      show_date_period,
      show_time,
      time_period_str,
      time_period_singular_str
    ),
  }
end

---@param data chronicles.ChroniclesData
---@param canonical_month_str string
---@param start_date? string
---@param end_date? string
---@param n_months_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
---@param construct_most_worked_on_project_arr boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
M.get_dashboard_data_months = function(
  data,
  canonical_month_str,
  canonical_today_str,
  start_date,
  end_date,
  n_months_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str,
  construct_most_worked_on_project_arr
)
  local time = require('dev-chronicles.core.time')

  start_date = start_date or time.get_previous_month(canonical_month_str, n_months_by_default - 1)
  end_date = end_date or canonical_month_str
  local start_ts = time.convert_month_str_to_timestamp(start_date)
  local end_ts = time.convert_month_str_to_timestamp(end_date, true)

  if start_ts > end_ts then
    vim.notify(('DevChronicles Error: start (%s) > end (%s)'):format(start_date, end_date))
    return
  end

  local final_time_period_str = time.get_time_period_str_months(
    start_date,
    end_date,
    canonical_month_str,
    canonical_today_str,
    show_date_period,
    show_time,
    time_period_str,
    time_period_singular_str
  )
  local most_worked_on_project_per_month = construct_most_worked_on_project_arr and {} or nil

  local filtered_projects = M._filter_projects_by_period(data.projects, start_ts, end_ts)

  if next(filtered_projects) == nil then
    if construct_most_worked_on_project_arr then
      vim.notify(tostring(end_ts))
      vim.notify(tostring(start_ts))
      vim.notify(tostring(math.floor(math.abs(end_ts - start_ts) / (86400 * 31))))
      vim.notify(tostring((86400 * 31)))
      vim.notify(tostring(math.floor(math.abs(end_ts - start_ts))))
      local n_months_this_period = math.floor(math.abs(end_ts - start_ts) / (86400 * 31)) + 1
      for i = 1, n_months_this_period do
        most_worked_on_project_per_month[i] = false
      end
    end
    return {
      global_time = 0,
      global_time_filtered = 0,
      projects_filtered_parsed = nil,
      time_period_str = final_time_period_str,
    },
      most_worked_on_project_per_month
  end

  ---@type chronicles.Dashboard.Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0

  local l_pointer_month, l_pointer_year = time.extract_month_year(start_date)
  local r_pointer_month, r_pointer_year = time.extract_month_year(end_date)

  local i = 0
  while true do
    i = i + 1
    local month_max_time = 0
    ---@type string|boolean
    local month_max_project = false
    local curr_date_key = string.format('%02d.%d', l_pointer_month, l_pointer_year)

    for project_id, project_data in pairs(filtered_projects) do
      local month_time = project_data.by_month[curr_date_key]
      if month_time then
        local filtered_project_data = projects_filtered_parsed[project_id]
        if not filtered_project_data then
          filtered_project_data = {
            total_time = 0,
            last_worked = project_data.last_worked,
            last_worked_canonical = project_data.last_worked_canonical, -- TODO: This is not used later, remove it after fixing the types. first_worked too
            first_worked = project_data.first_worked,
            tags_map = project_data.tags_map,
            total_global_time = project_data.total_time,
          }
          projects_filtered_parsed[project_id] = filtered_project_data
        end
        filtered_project_data.total_time = filtered_project_data.total_time + month_time
        global_time_filtered = global_time_filtered + month_time

        if construct_most_worked_on_project_arr and month_time > month_max_time then
          month_max_time = month_time
          month_max_project = project_id
        end
      end
    end

    if construct_most_worked_on_project_arr then
      most_worked_on_project_per_month[i] = month_max_project
    end

    if l_pointer_month == r_pointer_month and l_pointer_year == r_pointer_year then
      break
    end

    l_pointer_month = l_pointer_month + 1
    if l_pointer_month == 13 then
      l_pointer_month = 1
      l_pointer_year = l_pointer_year + 1
    end
  end

  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    projects_filtered_parsed = projects_filtered_parsed,
    time_period_str = final_time_period_str,
  },
    most_worked_on_project_per_month
end

---@param data chronicles.ChroniclesData
---@param canonical_today_str string
---@param start_offset? integer
---@param end_offset? integer
---@param n_days_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
---@param construct_most_worked_on_project_arr boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
M.get_dashboard_data_days = function(
  data,
  canonical_today_str,
  start_offset,
  end_offset,
  n_days_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str,
  construct_most_worked_on_project_arr
)
  local time = require('dev-chronicles.core.time')

  start_offset = start_offset or n_days_by_default - 1
  end_offset = end_offset or 0

  local DAY_SEC = 86400 -- 24 * 60 * 60
  local start_str = time.get_previous_day(canonical_today_str, start_offset)
  local end_str = time.get_previous_day(canonical_today_str, end_offset)
  local start_timestamp = time.convert_day_str_to_timestamp(start_str)
  local end_timestamp = time.convert_day_str_to_timestamp(end_str, true)

  if start_timestamp > end_timestamp then
    vim.notify(('DevChronicles Error: start (%s) > end (%s)'):format(start_str, end_str))
    return
  end

  local final_time_period_str = time.get_time_period_str_days(
    start_offset - end_offset + 1,
    start_str,
    end_str,
    canonical_today_str,
    show_date_period,
    show_time,
    time_period_str,
    time_period_singular_str
  )
  local most_worked_on_project_per_day = construct_most_worked_on_project_arr and {} or nil

  local filtered_projects =
    M._filter_projects_by_period(data.projects, start_timestamp, end_timestamp)

  if next(filtered_projects) == nil then
    if construct_most_worked_on_project_arr then
      local n_days_this_period = math.floor(math.abs(end_timestamp - start_timestamp) / DAY_SEC) + 1
      for i = 1, n_days_this_period do
        most_worked_on_project_per_day[i] = false
      end
    end
    return {
      global_time = 0,
      global_time_filtered = 0,
      projects_filtered_parsed = nil,
      time_period_str = final_time_period_str,
    },
      most_worked_on_project_per_day
  end

  ---@type chronicles.Dashboard.Stats.ParsedProjects
  local projects_filtered_parsed = {}
  local global_time_filtered = 0

  local i = 0
  for ts = start_timestamp, end_timestamp, DAY_SEC do
    i = i + 1
    local day_max_time = 0
    ---@type string|boolean
    local day_max_project = false
    local key = time.get_day_str(ts)

    for project_id, project_data in pairs(filtered_projects) do
      local day_time = project_data.by_day[key]
      if day_time then
        local accum_proj_data = projects_filtered_parsed[project_id]
        if not accum_proj_data then
          accum_proj_data = {
            total_time = 0,
            last_worked = project_data.last_worked,
            last_worked_canonical = project_data.last_worked_canonical,
            first_worked = project_data.first_worked,
            tags_map = project_data.tags_map,
            total_global_time = project_data.total_time,
          }
          projects_filtered_parsed[project_id] = accum_proj_data
        end
        accum_proj_data.total_time = accum_proj_data.total_time + day_time
        global_time_filtered = global_time_filtered + day_time

        if construct_most_worked_on_project_arr and day_time > day_max_time then
          day_max_time = day_time
          day_max_project = project_id
        end
      end
    end

    if construct_most_worked_on_project_arr then
      most_worked_on_project_per_day[i] = day_max_project
    end
  end

  ---@type chronicles.Dashboard.Data
  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    projects_filtered_parsed = projects_filtered_parsed,
    time_period_str = final_time_period_str,
  },
    most_worked_on_project_per_day
end

--- TODO: Set it to nil inplace
---@param projects table<string, chronicles.ChroniclesData.ProjectData>
---@param start_ts integer
---@param end_ts integer
---@return table<string, chronicles.ChroniclesData.ProjectData>
M._filter_projects_by_period = function(projects, start_ts, end_ts)
  local filtered_projects = {}
  for project_id, project_data in pairs(projects) do
    if project_data.first_worked <= end_ts and project_data.last_worked_canonical >= start_ts then
      filtered_projects[project_id] = project_data
    end
  end
  return filtered_projects
end

return M
