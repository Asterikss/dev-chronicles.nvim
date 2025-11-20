local M = {}

local time = require('dev-chronicles.core.time')
local time_days = require('dev-chronicles.core.time.days')
local notify = require('dev-chronicles.utils.notify')

---Accepts a year string in format 'YYYY' and transforms it into a unix timestamp.
---If `end_of_year` is true, returns the last possible timestamp within that year.
---@param year_str string Year in format: 'YYYY'
---@param end_of_year? boolean Should the end of year timestamp be returned
---@return integer: timestamp
function M.convert_year_str_to_timestamp(year_str, end_of_year)
  local year = M.str_to_year(year_str)
  -- if end_of_year: bump to first of next year, otherwise first of this year
  local ts = os.time({
    year = year + (end_of_year and 1 or 0),
    month = 1,
    day = 1,
    hour = 0,
    min = 0,
    sec = 0,
  })
  -- if end_of_year, subtract 1 sec to get last second of the requested year
  return end_of_year and (ts - 1) or ts
end

---Returns the previous year to `start_year` as a string. Both formated as:
---'YYYY'. Offset can be passed to change how many years back to go
---(defaults to 1).
---@param start_year string From which year to offset ('YYYY')
---@param offset? integer How many years back to go (default 1)
---@return string
function M.get_previous_year(start_year, offset)
  offset = offset or 1
  local year = assert(tonumber(start_year), 'invalid year string')
  return tostring(year - offset)
end

---@param timestamp? integer
---@return string
function M.get_year_str(timestamp)
  ---@type string
  return os.date('%Y', timestamp)
end

---Format the time period between `start_year` and `end_year`.
---If `end_year` is the current year the period ends at the current date.
---If `time_period_str` is supplied, it is used for formatting instead.
---
---Result depends on the two boolean flags:
---  show_date_period  – include the year range (e.g. 2020–2025)
---  show_time       – append the duration (e.g. 5y, 3d, ...)
---
---@param start_year string 'YYYY'
---@param end_year string 'YYYY'
---@param canonical_year_str string 'YYYY'
---@param canonical_today_str string 'DD.MM.YYYY'
---@param period_indicator_opts chronicles.Options.Common.Header.PeriodIndicator
---@return string
function M.get_time_period_str_years(
  start_year,
  end_year,
  canonical_year_str,
  canonical_today_str,
  period_indicator_opts
)
  -- -- caller wants a custom numeric placeholder
  if start_year == end_year and period_indicator_opts.time_period_str_singular then
    return period_indicator_opts.time_period_str_singular:format(1)
  end

  if period_indicator_opts.time_period_str then
    local sy = assert(tonumber(start_year), 'bad start_year')
    local ey = assert(tonumber(end_year), 'bad end_year')
    return period_indicator_opts.time_period_str:format(ey - sy + 1)
  end
  -- --

  local period = ''
  local does_end_at_curr_year = end_year == canonical_year_str

  if period_indicator_opts.date_range then
    if start_year == end_year then
      period = start_year
    else
      period = start_year .. ' — ' .. end_year
    end
  end

  if does_end_at_curr_year then
    local day, month, _ = time_days.extract_day_month_year(canonical_today_str)
    period = ('%s [%02d.%02d]'):format(period, day, month)
  end

  if period_indicator_opts.days_count then
    local start_ts = M.convert_year_str_to_timestamp(start_year, false)

    local end_ts = does_end_at_curr_year and os.time()
      or M.convert_year_str_to_timestamp(end_year, true)

    local total_time = time.format_time(end_ts - start_ts, false)

    if period_indicator_opts.date_range then
      period = period .. ' (' .. total_time .. ')'
    else
      period = total_time
    end
  end

  return period
end

---@param year_str string (YYYY)
---@param start_year string (YYYY)
---@param end_year string (YYYY)
---@return boolean True
function M.is_year_in_range(year_str, start_year, end_year)
  local year = tonumber(year_str)
  local start = tonumber(start_year)
  local ending = tonumber(end_year)

  if not (year and start and ending) then
    notify.fatal('All inputs must be valid year strings (YYYY).')
  end

  return start <= year and year <= ending
end

---@param year_str string (YYYY)
---@return number
function M.str_to_year(year_str)
  local y = tonumber(year_str)
  if not (y and y >= 1 and y <= 9999) then
    notify.fatal('Invalid year string date (YYYY): ' .. year_str)
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return y
end

return M
