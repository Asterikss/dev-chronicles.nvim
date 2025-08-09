local M = {}

---Returns current timestamp and current day string, respecing
---extend_today_to_4am flag. If extend_today_to_4am being true
---causes today's calendar day to be shifted to yesterday, then the
---returned timestamp is shifted to be 23:59:59 of yesterday. If
---timestamp is passed, it is used instead of os.time(). This
---function was constructed to optimize the ammount of calls to
---os.time(...)
---@param extend_today_to_4am boolean
---@param timestamp? integer
---@return integer
---@return string 'DD.MM.YYYY'
M.get_canonical_curr_ts_and_day_str = function(extend_today_to_4am, timestamp)
  local ts = timestamp or os.time()
  local day_key = M.get_day_str(ts, extend_today_to_4am)

  if extend_today_to_4am and M.is_time_before_4am(ts) then
    ts = M.convert_day_str_to_timestamp(day_key, true)
  end

  return ts, day_key
end

---Returns current unix timestamp
---@return integer
M.get_current_timestamp = function()
  return os.time()
end

---Return seconds as a formatted time string
---@param seconds integer Seconds
---@param max_hours? boolean Should the maximal unit be hours (default true)
---@param min_hours? boolean Should the minimal unit be hours (default false)
---@param round_hours_above_one? boolean Should hours above 1 be rounded (default false)
---@return string
M.format_time = function(seconds, max_hours, min_hours, round_hours_above_one)
  max_hours = (max_hours == nil) and true or max_hours

  if seconds == 0 then
    return '0'
  end

  if seconds < 60 then
    if min_hours then
      return '0.1h'
    end
    return ('%ds'):format(seconds)
  end

  if seconds < 3600 then
    if min_hours then
      return ('%.1fh'):format(math.max(0.1, seconds / 3600))
    end
    return ('%dm'):format(seconds / 60)
  end

  if max_hours or seconds < 86400 then
    if round_hours_above_one then
      return ('%dh'):format(math.floor((seconds / 3600) + 0.5))
    end
    return ('%.1fh'):format(seconds / 3600)
  end

  local n_days = math.floor(seconds / 86400 + 0.5)
  if n_days == 1 then
    return '1 day'
  end
  return ('%d days'):format(n_days)
end

---Returns the day as a string in the format 'DD.MM.YYYY'.
---If a timestamp is provided, returns the day for that timestamp;
---otherwise, returns today's date.
---@param timestamp? integer
---@param extend_today_to_4am? boolean
---@return string
M.get_day_str = function(timestamp, extend_today_to_4am)
  local ts = timestamp or os.time()
  if extend_today_to_4am and M.is_time_before_4am(ts) then
    ts = ts - 86400
  end
  ---@type string
  return os.date('%d.%m.%Y', ts)
end

---Returns the month as a string in the format 'MM.YYYY'.
---If a timestamp is provided, returns the month for that timestamp;
---otherwise, returns the current month.
---@param timestamp? integer
---@return string
M.get_month_str = function(timestamp)
  ---@type string
  return os.date('%m.%Y', timestamp)
end

---Accepts a day-month-year string in format: 'DD.MM.YYYY' and extracts day,
---month, and year from it, turning them to integers.
---@param day_month_year_str string Date in format: 'DD.MM.YYYY'
---@return integer, integer, integer: day, month, year
M.extract_day_month_year = function(day_month_year_str)
  local day, month, year = day_month_year_str:match('(%d%d).(%d%d)%.(%d%d%d%d)')
  day = tonumber(day)
  month = tonumber(month)
  year = tonumber(year)
  if not day or not month or not year then
    -- TODO:
    error('Invalid day-month-year string date: ' .. tostring(day_month_year_str))
  end
  return day, month, year
end

---Accepts a month-year string in format: 'MM.YYYY' and extracts month
---and year from it, turning them to integers.
---@param month_year_str string Date in format: 'MM.YYYY'
---@return integer, integer: month, year
M.extract_month_year = function(month_year_str)
  local month, year = month_year_str:match('(%d%d)%.(%d%d%d%d)')
  month = tonumber(month)
  year = tonumber(year)
  if not month or not year then
    error('Invalid month-year string date: ' .. tostring(month_year_str))
  end
  return month, year
end

---Returns the previous day to `start_day` as a string. Both formatted as:
---'DD.MM.YYYY'. Offset can be passed to change how many days back to go
---(default 1). If 0 is passed as an offset, the same start_day is returned.
---@param start_day string From which day to offset ('DD.MM.YYYY')
---@param offset? integer How many days back to go (default 1)
---@return string
M.get_previous_day = function(start_day, offset)
  offset = offset or 1
  if offset < 0 then
    vim.notify(
      'DevChronicles Warning: Offset, when getting previous day, cannot be '
        .. 'smaller than 0. Setting it to 1'
    )
    offset = 1
  end

  if offset == 0 then
    -- checks if its a valid date
    M.extract_day_month_year(start_day)
    return start_day
  end

  local day, month, year = M.extract_day_month_year(start_day)
  -- construct a timestamp at midnight UTC of that day
  local ts = os.time { year = year, month = month, day = day, hour = 0 }
  -- subtract the offset in seconds
  local prev_ts = ts - offset * 86400 -- 24 * 60 * 60

  ---@type string
  return os.date('%d.%m.%Y', prev_ts)
end

---Returns the previous month to `start_month` as a string. Both formated as:
---'MM.YYYY'. Offset can be passed to change how many months back to go
---(defaults to 1).
---@param start_month string From which month to offset ('MM.YYYY')
---@param offset? integer How many months back to go (default 1)
---@return string
M.get_previous_month = function(start_month, offset)
  offset = offset or 1
  if offset < 0 then
    vim.notify(
      'DevChronicesl Warning: Offset, when getting previous month, cannot be smaller than 0. Setting it to one'
    )
    offset = 1
  end

  local month, year = M.extract_month_year(start_month)

  month = month - offset
  while month <= 0 do
    month = month + 12
    year = year - 1
  end

  return string.format('%02d.%d', month, year)
end

---Accepts a day-month-year string in format: 'DD.MM.YYYY' and transforms it into a
---unix timestamp. If `end_of_day` is true, returns the last possible timestamp
---within that day.
---@param day_month_year_str string Date in format: 'DD.MM.YYYY'
---@param end_of_day? boolean Should the end of day timestamp be returned
---@return integer unix timestamp
M.convert_day_str_to_timestamp = function(day_month_year_str, end_of_day)
  local day, month, year = M.extract_day_month_year(day_month_year_str)
  -- bump to next day when end_of_day is requested
  local ts = os.time {
    year = year,
    month = month,
    day = day + (end_of_day and 1 or 0),
    hour = 0,
    min = 0,
    sec = 0,
  }
  -- if end_of_day, subtract 1s to get last second of the requested day
  return end_of_day and (ts - 1) or ts
end

---Accepts a month-year string in format: 'MM.YYYY' and transforms it into a
---unix timestamp. If `end_of_month` is true, returns the last possible timestamp
---within that month.
---@param month_year_str string Date in format: 'MM.YYYY'
---@param end_of_month? boolean Should the end of month timestamp be returned
---@return integer unix timestamp
M.convert_month_str_to_timestamp = function(month_year_str, end_of_month)
  local month, year = M.extract_month_year(month_year_str)
  -- if end_of_month: bump to first of next month, otherwise first of this month
  local ts = os.time {
    year = year,
    month = month + (end_of_month and 1 or 0),
    day = 1,
    hour = 0,
    min = 0,
    sec = 0,
  }
  -- if end_of_month, subtract 1 sec to get last second of the requested month
  return end_of_month and (ts - 1) or ts
end

---@param n_days integer
---@param start_day string 'DD.MM.YYYY'
---@param end_day string 'DD.MM.YYYY'
---@param canonical_today_str string 'DD.MM.YYYY'
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
---@return string
M.get_time_period_str_days = function(
  n_days,
  start_day,
  end_day,
  canonical_today_str,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str
)
  local is_singular = n_days == 1
  local ends_today = end_day == canonical_today_str

  if ends_today then
    local template = is_singular and time_period_singular_str or time_period_str
    if template then
      return template:format(n_days)
    end
  end

  local time_period = ''
  if show_date_period then
    if is_singular then
      time_period = start_day
    else
      local start_d, start_m, start_y = M.extract_day_month_year(start_day)
      local end_d, end_m, end_y = M.extract_day_month_year(end_day)
      if start_y == end_y and start_m == end_m then
        -- Same month: DD-DD.MM.YYYY
        time_period = ('%02d — %02d.%02d.%04d'):format(start_d, end_d, start_m, start_y)
      else
        -- Different months or years: DD.MM.YYYY - DD.MM.YYYY
        time_period = start_day .. ' — ' .. end_day
      end
    end
  end

  if show_time then
    local ending = is_singular and ' day' or ' days'
    if show_date_period then
      time_period = time_period .. ' (' .. n_days .. ending .. ')'
    else
      time_period = time_period .. ending
    end
  end
  return time_period
end

---Format the time period between `start_month` and `end_month`.
---If `end_month` is the current month the period ends at the current date.
---If `time_period_str` string is supplied, it's used for formatting instead.
---
---Result depends on the two boolean flags:
---  show_date_period  – include the day range (e.g. 23.11-26.11.2025)
---  show_time       – append the duration (e.g. 3d, 5h, ...)
---
---@param start_month string 'MM.YYYY'
---@param end_month string 'MM.YYYY'
---@param canonical_month_str string 'MM.YYYY'
---@param canonical_today_str string 'MM.YYYY'
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_singular_str? string
---@return string
M.get_time_period_str_months = function(
  start_month,
  end_month,
  canonical_month_str,
  canonical_today_str,
  show_date_period,
  show_time,
  time_period_str,
  time_period_singular_str
)
  if start_month == end_month and time_period_singular_str then
    return string.format(time_period_singular_str, 1)
  end
  if time_period_str then
    local start_ts = M.convert_month_str_to_timestamp(start_month)
    local end_ts = M.convert_month_str_to_timestamp(end_month)
    local earlier_date = os.date('*t', start_ts)
    local later_date = os.date('*t', end_ts)

    local year_diff = later_date.year - earlier_date.year
    local month_diff = later_date.month - earlier_date.month

    return string.format(time_period_str, year_diff * 12 + month_diff)
  end

  local time_period = ''
  local is_current_month = end_month == canonical_month_str

  if show_date_period then
    local month_start, year_start = M.extract_month_year(start_month)
    local month_end, year_end = M.extract_month_year(end_month)

    if year_start == year_end then
      if month_start == month_end then
        if is_current_month then
          time_period = '01.' .. start_month .. ' — ' .. canonical_today_str
        else
          time_period = start_month
        end
      else
        if is_current_month then
          time_period = '01.' .. string.sub(start_month, 1, 2) .. ' — ' .. canonical_today_str
        else
          time_period = string.sub(start_month, 1, 2)
            .. '—'
            .. string.sub(end_month, 1, 2)
            .. '.'
            .. year_start
        end
      end
    else
      time_period = start_month .. ' — ' .. end_month
    end
  end

  if show_time then
    local start_ts = M.convert_month_str_to_timestamp(start_month)

    local end_ts = is_current_month and os.time()
      or M.convert_month_str_to_timestamp(end_month, true)

    local total_time = M.format_time(end_ts - start_ts, false)

    if show_date_period then
      time_period = time_period .. ' (' .. total_time .. ')'
    else
      time_period = total_time
    end
  end

  return time_period
end

---@param ts? integer
---@return boolean
M.is_time_before_4am = function(ts)
  return tonumber(os.date('%H', ts)) <= 3
end

return M
