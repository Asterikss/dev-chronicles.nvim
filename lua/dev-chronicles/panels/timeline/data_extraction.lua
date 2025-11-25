local M = {}

local notify = require('dev-chronicles.utils.notify')
local get_project_name = require('dev-chronicles.utils.strings').get_project_name
local closure_get_project_highlight =
  require('dev-chronicles.core.colors').closure_get_project_highlight

---@param data chronicles.ChroniclesData
---@param canonical_today_str string
---@param n_days_by_default integer
---@param timeline_type_options_header chronicles.Options.Timeline.Header
---@param abbr_labels_opts chronicles.Options.Timeline.Section.SegmentAbbrLabels
---@param optimize_storage_for_x_days integer
---@param differentiate_projects_by_folder_not_path boolean
---@param start_offset? integer
---@param end_offset? integer
---@return chronicles.Timeline.Data?
function M.get_timeline_data_days(
  data,
  canonical_today_str,
  n_days_by_default,
  timeline_type_options_header,
  abbr_labels_opts,
  optimize_storage_for_x_days,
  differentiate_projects_by_folder_not_path,
  start_offset,
  end_offset
)
  local time_days = require('dev-chronicles.core.time.days')

  start_offset = start_offset or n_days_by_default - 1
  end_offset = end_offset or 0

  local DAY_SEC = 86400
  local start_str = time_days.get_previous_day(canonical_today_str, start_offset)
  local end_str = time_days.get_previous_day(canonical_today_str, end_offset)
  local unnormalized_start_ts = time_days.convert_day_str_to_timestamp(start_str)
  -- Adding half a day handles DST issues given any reasonable time range. Not pretty, but performant
  local start_ts = unnormalized_start_ts + 43200
  local end_ts = time_days.convert_day_str_to_timestamp(end_str, true)
  local canonical_today_timestamp = time_days.convert_day_str_to_timestamp(canonical_today_str)
  local projects = data.projects

  if start_ts > end_ts then
    notify.warn(('start (%s) > end (%s)'):format(start_str, end_str))
    return
  end

  if optimize_storage_for_x_days then
    local oldest_allowed_ts = time_days.convert_day_str_to_timestamp(
      time_days.get_previous_day(canonical_today_str, optimize_storage_for_x_days - 1)
    )

    if start_ts < oldest_allowed_ts then
      notify.warn(
        ('start date of the requested period — %s — is older than the last %d stored days (optimize_storage_for_x_days). Since the storage optimization is done lazily, the data past this point could be incorrect. To see it, increase the optimize_storage_for_x_days option.'):format(
          start_str,
          optimize_storage_for_x_days
        )
      )
      return
    end
  end

  require('dev-chronicles.dashboard.data_extraction')._filter_projects_by_period_inplace(
    projects,
    start_ts,
    end_ts
  )

  ---@type chronicles.Timeline.SegmentData[]
  local segments, len_segments = {}, 0
  ---@type table<string, string>
  local project_id_to_highlight = {}
  local max_segment_time = 0
  local total_period_time = 0

  local orig_locale
  if abbr_labels_opts.locale then
    orig_locale = os.setlocale(nil, 'time')
    os.setlocale(abbr_labels_opts.locale, 'time')
  end

  if next(projects) ~= nil then
    for ts = start_ts, end_ts, DAY_SEC do
      ---@type chronicles.Timeline.SegmentData.ProjectShare[]
      local project_shares, len_project_shares = {}, 0
      local total_segment_time = 0
      local key = time_days.get_day_str(ts) -- DD.MM.YYYY
      local day, month, year = key:sub(1, 2), key:sub(4, 5), key:sub(7, 10)
      local dow_abbr = os.date('%a', ts) --[[@as string]]

      for project_id, project_data in pairs(projects) do
        local day_time = project_data.by_day[key]
        if day_time then
          total_segment_time = total_segment_time + day_time
          len_project_shares = len_project_shares + 1
          project_shares[len_project_shares] = { project_id = project_id, share = day_time }
        end
      end

      if total_segment_time > 0 then
        total_period_time = total_period_time + total_segment_time
        max_segment_time = math.max(max_segment_time, total_segment_time)

        table.sort(project_shares, function(a, b)
          return a.share < b.share
        end)

        for j = 1, len_project_shares do
          project_shares[j].share = project_shares[j].share / total_segment_time
        end
      end

      len_segments = len_segments + 1
      segments[len_segments] = {
        date_key = key,
        day = day,
        month = month,
        year = year,
        date_abbr = dow_abbr,
        total_segment_time = total_segment_time,
        project_shares = project_shares,
      }
    end
  end

  if abbr_labels_opts.locale then
    os.setlocale(orig_locale, 'time')
  end

  local get_project_color = closure_get_project_highlight(true, false, -1)

  for project_id, project_data in pairs(projects) do
    local project_name = differentiate_projects_by_folder_not_path and project_id
      or get_project_name(project_id)
    project_id_to_highlight[project_name] = get_project_color(project_data.color)
  end

  ---@type chronicles.Timeline.Data
  return {
    total_period_time = total_period_time,
    segments = next(segments) ~= nil and segments or nil,
    max_segment_time = max_segment_time,
    does_include_curr_date = canonical_today_timestamp >= unnormalized_start_ts
      and canonical_today_timestamp <= end_ts,
    time_period_str = time_days.get_time_period_str_days(
      start_offset - end_offset + 1,
      start_str,
      end_str,
      canonical_today_str,
      timeline_type_options_header.period_indicator
    ),
    project_id_to_highlight = project_id_to_highlight,
  }
end

return M
