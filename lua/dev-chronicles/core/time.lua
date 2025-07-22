local M = {}

---Returns the day as a string in the format 'DD.MM.YYYY'.
---If a timestamp is provided, returns the day for that timestamp;
---otherwise, returns today's date.
---@param timestamp? integer
---@return string
M.get_day_str = function(timestamp)
  ---@type string
  return os.date('%d.%m.%Y', timestamp)
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
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@return string
M.get_time_period_str_days = function(
  n_days,
  start_day,
  end_day,
  show_date_period,
  show_time,
  time_period_str
)
  if time_period_str then
    return string.format(time_period_str, n_days)
  end
  local time_period = ''
  if show_date_period then
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

  if show_time then
    if show_date_period then
      time_period = time_period .. ' (' .. n_days .. ' days)'
    else
      time_period = n_days .. ' days'
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
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@return string
M.get_time_period_str_months = function(
  start_month,
  end_month,
  show_date_period,
  show_time,
  time_period_str
)
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
  local current_month = M.get_month_str()

  if show_date_period then
    local month_start, year_start = M.extract_month_year(start_month)
    local month_end, year_end = M.extract_month_year(end_month)

    -- Its presence signifies that end_month is the current month
    local day_month_str = current_month == end_month and M.get_day_str() or nil

    if year_start == year_end then
      if month_start == month_end then
        if day_month_str then
          time_period = '01.' .. start_month .. ' — ' .. day_month_str
        else
          time_period = start_month
        end
      else
        if day_month_str then
          time_period = '01.' .. string.sub(start_month, 1, 2) .. '—' .. day_month_str
        else
          time_period = string.sub(start_month, 1, 2)
            .. '—'
            .. string.sub(end_month, 1, 2)
            .. '.'
            .. year_start
        end
      end
    else
      time_period = start_month .. '—' .. end_month
    end
  end

  if show_time then
    local start_ts = M.convert_month_str_to_timestamp(start_month)

    local end_ts = current_month == end_month and M.get_current_timestamp()
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

return M
