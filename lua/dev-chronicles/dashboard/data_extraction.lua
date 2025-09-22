local M = {}

local time = require('dev-chronicles.core.time')
local notify = require('dev-chronicles.utils.notify')

-- TODO: return type
---@param data chronicles.ChroniclesData
---@param canonical_month_str string
---@param canonical_today_str string
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_str_singular? string
function M.get_dashboard_data_all(
  data,
  canonical_month_str,
  canonical_today_str,
  show_date_period,
  show_time,
  time_period_str,
  time_period_str_singular
)
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
      time_period_str_singular
    ),
  }
end

---@param data chronicles.ChroniclesData
---@param session_base chronicles.SessionBase
---@param start_date? string
---@param end_date? string
---@param n_months_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_str_singular? string
---@param construct_most_worked_on_project_arr boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
function M.get_dashboard_data_months(
  data,
  session_base,
  start_date,
  end_date,
  n_months_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_str_singular,
  construct_most_worked_on_project_arr
)
  start_date = start_date
    or time.get_previous_month(session_base.canonical_month_str, n_months_by_default - 1)
  end_date = end_date or session_base.canonical_month_str

  local start_ts = time.convert_month_str_to_timestamp(start_date)
  local end_ts = time.convert_month_str_to_timestamp(end_date, true)
  local projects = data.projects

  if start_ts > end_ts then
    notify.warn(('DevChronicles Error: start (%s) > end (%s)'):format(start_date, end_date))
    return
  end

  M._filter_projects_by_period_inplace(projects, start_ts, end_ts)

  ---@type chronicles.Dashboard.FinalProjectDataMap
  local projects_filtered_parsed = {}
  ---@type chronicles.Dashboard.FinalProjectData[]
  local arr_projects = {}
  local len_arr_projects = 0
  local max_project_time = 0
  local global_time_filtered = 0
  local most_worked_on_project_per_month = construct_most_worked_on_project_arr and {} or nil

  local l_pointer_month, l_pointer_year = time.extract_month_year(start_date)
  local r_pointer_month, r_pointer_year = time.extract_month_year(end_date)

  if projects then
    local i = 0
    while true do
      i = i + 1
      local month_max_time = 0
      ---@type string|boolean
      local month_max_project = false

      local year_str = string.format('%d', l_pointer_year)
      local month_str = string.format('%02d.%d', l_pointer_month, l_pointer_year)

      for project_id, project_data in pairs(projects) do
        local month_time = project_data.by_year[year_str]
          and project_data.by_year[year_str].by_month[month_str]

        if month_time then
          local filtered_project_data = projects_filtered_parsed[project_id]
          if not filtered_project_data then
            filtered_project_data = {
              id = project_id,
              total_time = 0,
              last_worked = project_data.last_worked,
              last_worked_canonical = project_data.last_worked_canonical,
              first_worked = project_data.first_worked,
              tags_map = project_data.tags_map,
              global_time = project_data.total_time,
            }
            projects_filtered_parsed[project_id] = filtered_project_data
            len_arr_projects = len_arr_projects + 1
            arr_projects[len_arr_projects] = filtered_project_data
          end
          filtered_project_data.total_time = filtered_project_data.total_time + month_time
          global_time_filtered = global_time_filtered + month_time
          max_project_time = math.max(max_project_time, filtered_project_data.total_time)

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
  end

  if next(projects_filtered_parsed) == nil and construct_most_worked_on_project_arr then
    for i = 1, ((r_pointer_year - l_pointer_year) * 12 + (r_pointer_month - l_pointer_month) + 1) do
      most_worked_on_project_per_month[i] = false
    end
  end

  ---@type chronicles.Dashboard.Data
  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    final_project_data_arr = next(arr_projects) and arr_projects or nil,
    max_project_time = max_project_time,
    does_include_curr_date = time.is_month_in_range(
      session_base.canonical_month_str,
      start_date,
      end_date
    ),
    time_period_str = time.get_time_period_str_months(
      start_date,
      end_date,
      session_base.canonical_month_str,
      session_base.canonical_today_str,
      show_date_period,
      show_time,
      time_period_str,
      time_period_str_singular
    ),
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
---@param time_period_str_singular? string
---@param construct_most_worked_on_project_arr boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
function M.get_dashboard_data_days(
  data,
  canonical_today_str,
  start_offset,
  end_offset,
  n_days_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_str_singular,
  construct_most_worked_on_project_arr
)
  start_offset = start_offset or n_days_by_default - 1
  end_offset = end_offset or 0

  local DAY_SEC = 86400 -- 24 * 60 * 60
  local start_str = time.get_previous_day(canonical_today_str, start_offset)
  local end_str = time.get_previous_day(canonical_today_str, end_offset)
  local start_ts = time.convert_day_str_to_timestamp(start_str)
  local end_ts = time.convert_day_str_to_timestamp(end_str, true)
  local canonical_today_timestamp = time.convert_day_str_to_timestamp(canonical_today_str)
  local projects = data.projects

  if start_ts > end_ts then
    notify.warn(('DevChronicles Error: start (%s) > end (%s)'):format(start_str, end_str))
    return
  end

  M._filter_projects_by_period_inplace(projects, start_ts, end_ts)

  ---@type chronicles.Dashboard.FinalProjectDataMap
  local projects_filtered_parsed = {}
  ---@type chronicles.Dashboard.FinalProjectData[]
  local arr_projects = {}
  local len_arr_projects = 0
  local max_project_time = 0
  local global_time_filtered = 0
  local most_worked_on_project_per_day = construct_most_worked_on_project_arr and {} or nil

  if projects then
    local i = 0
    for ts = start_ts, end_ts, DAY_SEC do
      i = i + 1
      local day_max_time = 0
      ---@type string|boolean
      local day_max_project = false
      local key = time.get_day_str(ts)

      for project_id, project_data in pairs(projects) do
        local day_time = project_data.by_day[key]
        if day_time then
          local accum_proj_data = projects_filtered_parsed[project_id]
          if not accum_proj_data then
            accum_proj_data = {
              id = project_id,
              total_time = 0,
              last_worked = project_data.last_worked,
              last_worked_canonical = project_data.last_worked_canonical,
              first_worked = project_data.first_worked,
              tags_map = project_data.tags_map,
              global_time = project_data.total_time,
            }
            projects_filtered_parsed[project_id] = accum_proj_data
            len_arr_projects = len_arr_projects + 1
            arr_projects[len_arr_projects] = accum_proj_data
          end
          accum_proj_data.total_time = accum_proj_data.total_time + day_time
          global_time_filtered = global_time_filtered + day_time
          max_project_time = math.max(max_project_time, accum_proj_data.total_time)

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
  end

  if next(projects_filtered_parsed) == nil and construct_most_worked_on_project_arr then
    local n_days_this_period = math.floor(math.abs(end_ts - start_ts) / DAY_SEC) + 1
    for i = 1, n_days_this_period do
      most_worked_on_project_per_day[i] = false
    end
  end

  ---@type chronicles.Dashboard.Data
  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    final_project_data_arr = next(arr_projects) and arr_projects or nil,
    max_project_time = max_project_time,
    does_include_curr_date = canonical_today_timestamp >= start_ts
      and canonical_today_timestamp <= end_ts,
    time_period_str = time.get_time_period_str_days(
      start_offset - end_offset + 1,
      start_str,
      end_str,
      canonical_today_str,
      show_date_period,
      show_time,
      time_period_str,
      time_period_str_singular
    ),
  },
    most_worked_on_project_per_day
end

---@param data chronicles.ChroniclesData
---@param session_base chronicles.SessionBase
---@param start_date? string
---@param end_date? string
---@param n_years_by_default integer
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_str_singular? string
---@param construct_most_worked_on_project_arr boolean
---@return chronicles.Dashboard.Data?, chronicles.Dashboard.TopProjectsArray?
function M.get_dashboard_data_years(
  data,
  session_base,
  start_date,
  end_date,
  n_years_by_default,
  show_date_period,
  show_time,
  time_period_str,
  time_period_str_singular,
  construct_most_worked_on_project_arr
)
  start_date = start_date
    or time_years.get_previous_year(session_base.canonical_year_str, n_years_by_default - 1)
  end_date = end_date or session_base.canonical_year_str

  local start_ts = time_years.convert_year_str_to_timestamp(start_date)
  local end_ts = time_years.convert_year_str_to_timestamp(end_date, true)
  local projects = data.projects

  if start_ts > end_ts then
    notify.warn(('DevChronicles Error: start (%s) > end (%s)'):format(start_date, end_date))
    return
  end

  M._filter_projects_by_period_inplace(projects, start_ts, end_ts)

  ---@type chronicles.Dashboard.FinalProjectDataMap
  local projects_filtered_parsed = {}
  ---@type chronicles.Dashboard.FinalProjectData[]
  local arr_projects = {}
  local len_arr_projects = 0
  local max_project_time = 0
  local global_time_filtered = 0
  local most_worked_on_project_per_year = construct_most_worked_on_project_arr and {} or nil

  local l_pointer_year = assert(tonumber(start_date), 'bad start_year')
  local r_pointer_year = assert(tonumber(end_date), 'bad start_year')

  if projects then
    local i = 0
    while true do
      i = i + 1
      local year_max_time = 0
      ---@type string|boolean
      local year_max_project = false
      local year_str = tostring(l_pointer_year)

      for project_id, project_data in pairs(projects) do
        local year_time = project_data.by_year[year_str]
          and project_data.by_year[year_str].total_time

        if year_time then
          local filtered_project_data = projects_filtered_parsed[project_id]
          if not filtered_project_data then
            filtered_project_data = {
              id = project_id,
              total_time = 0,
              last_worked = project_data.last_worked,
              last_worked_canonical = project_data.last_worked_canonical,
              first_worked = project_data.first_worked,
              tags_map = project_data.tags_map,
              global_time = project_data.total_time,
            }
            projects_filtered_parsed[project_id] = filtered_project_data
            len_arr_projects = len_arr_projects + 1
            arr_projects[len_arr_projects] = filtered_project_data
          end

          filtered_project_data.total_time = filtered_project_data.total_time + year_time
          global_time_filtered = global_time_filtered + year_time
          max_project_time = math.max(max_project_time, filtered_project_data.total_time)

          if construct_most_worked_on_project_arr and year_time > year_max_time then
            year_max_time = year_time
            year_max_project = project_id
          end
        end
      end

      if construct_most_worked_on_project_arr then
        most_worked_on_project_per_year[i] = year_max_project
      end

      if l_pointer_year == r_pointer_year then
        break
      end

      l_pointer_year = l_pointer_year + 1
    end
  end

  if next(projects_filtered_parsed) == nil and construct_most_worked_on_project_arr then
    for i = 1, (tonumber(end_date) - tonumber(start_date) + 1) do
      most_worked_on_project_per_year[i] = false
    end
  end

  ---@type chronicles.Dashboard.Data
  return {
    global_time = data.global_time,
    global_time_filtered = global_time_filtered,
    final_project_data_arr = next(arr_projects) and arr_projects or nil,
    max_project_time = max_project_time,
    does_include_curr_date = time_years.is_year_in_range(
      session_base.canonical_year_str,
      start_date,
      end_date
    ),
    time_period_str = time_years.get_time_period_str_years(
      start_date,
      end_date,
      session_base.canonical_year_str,
      session_base.canonical_today_str,
      show_date_period,
      show_time,
      time_period_str,
      time_period_str_singular
    ),
  },
    most_worked_on_project_per_year
end

---@param projects table<string, chronicles.ChroniclesData.ProjectData>
---@param start_ts integer
---@param end_ts integer
function M._filter_projects_by_period_inplace(projects, start_ts, end_ts)
  for project_id, project_data in pairs(projects) do
    if project_data.first_worked > end_ts or project_data.last_worked_canonical < start_ts then
      projects[project_id] = nil
    end
  end
end

return M
