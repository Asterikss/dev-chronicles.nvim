local M = {}

local time = require('dev-chronicles.core.time')
local notify = require('dev-chronicles.utils.notify')

---Returns the month as a string in the format 'MM.YYYY'.
---If a timestamp is provided, returns the month for that timestamp;
---otherwise, returns the current month.
---@param timestamp? integer
---@return string
function M.get_month_str(timestamp)
  ---@type string
  return os.date('%m.%Y', timestamp)
end

---Accepts a month-year string in format: 'MM.YYYY' and extracts month
---and year from it, turning them to integers.
---@param month_year_str string Date in format: 'MM.YYYY'
---@return integer, integer: month, year
function M.extract_month_year(month_year_str)
  local month, year = month_year_str:match('(%d%d)%.(%d%d%d%d)')
  month, year = tonumber(month), tonumber(year)
  if not (month and year) then
    notify.fatal('Invalid month-year string date (MM.YYYY): ' .. month_year_str)
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return month, year
end

---Returns the previous month to `start_month` as a string. Both formated as:
---'MM.YYYY'. Offset can be passed to change how many months back to go
---(defaults to 1).
---@param start_month string From which month to offset ('MM.YYYY')
---@param offset? integer How many months back to go (default 1)
---@return string
function M.get_previous_month(start_month, offset)
  offset = offset or 1
  if offset < 0 then
    notify.warn('Offset, when getting previous month, cannot be smaller than 0. Setting it to 1')
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

---Accepts a month-year string in format: 'MM.YYYY' and transforms it into a
---unix timestamp. If `end_of_month` is true, returns the last possible timestamp
---within that month.
---@param month_year_str string Date in format: 'MM.YYYY'
---@param end_of_month? boolean Should the end of month timestamp be returned
---@return integer unix timestamp
function M.convert_month_str_to_timestamp(month_year_str, end_of_month)
  local month, year = M.extract_month_year(month_year_str)
  -- if end_of_month: bump to first of next month, otherwise first of this month
  local ts = os.time({
    year = year,
    month = month + (end_of_month and 1 or 0),
    day = 1,
    hour = 0,
    min = 0,
    sec = 0,
  })
  -- if end_of_month, subtract 1 sec to get last second of the requested month
  return end_of_month and (ts - 1) or ts
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
---@param canonical_today_str string 'DD.MM.YYYY'
---@param period_indicator_opts chronicles.Options.Common.Header.PeriodIndicator
---@return string
function M.get_time_period_str_months(
  start_month,
  end_month,
  canonical_month_str,
  canonical_today_str,
  period_indicator_opts
)
  -- -- caller wants a custom numeric placeholder
  if start_month == end_month and period_indicator_opts.time_period_str_singular then
    return period_indicator_opts.time_period_str_singular:format(1)
  end

  if period_indicator_opts.time_period_str then
    local start_ts = M.convert_month_str_to_timestamp(start_month)
    local end_ts = M.convert_month_str_to_timestamp(end_month)
    local earlier_date = os.date('*t', start_ts)
    local later_date = os.date('*t', end_ts)

    local year_diff = later_date.year - earlier_date.year
    local month_diff = later_date.month - earlier_date.month

    return period_indicator_opts.time_period_str:format(year_diff * 12 + month_diff)
  end
  -- --

  local time_period = ''
  local is_current_month = end_month == canonical_month_str

  if period_indicator_opts.date_range then
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

  if period_indicator_opts.days_count then
    local start_ts = M.convert_month_str_to_timestamp(start_month)

    local end_ts = is_current_month and os.time()
      or M.convert_month_str_to_timestamp(end_month, true)

    local total_time = time.format_time(end_ts - start_ts, false)

    if period_indicator_opts.date_range then
      time_period = time_period .. ' (' .. total_time .. ')'
    else
      time_period = total_time
    end
  end

  return time_period
end

---@param month_str string
---@param start_month string
---@param end_month string
---@return boolean
function M.is_month_in_range(month_str, start_month, end_month)
  local y, m = M.extract_month_year(month_str)
  local sy, sm = M.extract_month_year(start_month)
  local ey, em = M.extract_month_year(end_month)

  local idx = y * 12 + m
  local sidx = sy * 12 + sm
  local eidx = ey * 12 + em

  return idx >= sidx and idx <= eidx
end

return M
