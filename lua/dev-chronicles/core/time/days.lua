local M = {}

local notify = require('dev-chronicles.utils.notify')

---@param ts? integer
---@return boolean
function M.is_time_before_4am(ts)
  return tonumber(os.date('%H', ts)) <= 3
end

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
function M.get_canonical_curr_ts_and_day_str(extend_today_to_4am, timestamp)
  local ts = timestamp or os.time()
  local day_key = M.get_day_str(ts, extend_today_to_4am)

  if extend_today_to_4am and M.is_time_before_4am(ts) then
    ts = M.convert_day_str_to_timestamp(day_key, true)
  end

  return ts, day_key
end

---Returns the day as a string in the format 'DD.MM.YYYY'.
---If a timestamp is provided, returns the day for that timestamp;
---otherwise, returns today's date.
---@param timestamp? integer
---@param extend_today_to_4am? boolean
---@return string
function M.get_day_str(timestamp, extend_today_to_4am)
  local ts = timestamp or os.time()
  if extend_today_to_4am and M.is_time_before_4am(ts) then
    ts = ts - 86400
  end
  ---@type string
  return os.date('%d.%m.%Y', ts)
end

---Accepts a day-month-year string in format: 'DD.MM.YYYY' and extracts day,
---month, and year from it, turning them to integers.
---@param day_month_year_str string Date in format: 'DD.MM.YYYY'
---@return integer, integer, integer: day, month, year
function M.extract_day_month_year(day_month_year_str)
  local day, month, year = day_month_year_str:match('(%d%d).(%d%d)%.(%d%d%d%d)')
  day, month, year = tonumber(day), tonumber(month), tonumber(year)
  if not (day and month and year) then
    notify.fatal('Invalid day-month-year string date: ' .. day_month_year_str)
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return day, month, year
end

---Returns the previous day to `start_day` as a string. Both formatted as:
---'DD.MM.YYYY'. Offset can be passed to change how many days back to go
---(default 1). If 0 is passed as an offset, the same start_day is returned.
---@param start_day string From which day to offset ('DD.MM.YYYY')
---@param offset? integer How many days back to go (default 1)
---@return string
function M.get_previous_day(start_day, offset)
  offset = offset or 1
  if offset < 0 then
    notify.warn('Offset, when getting previous day, cannot be smaller than 0. Setting it to 1')
    offset = 1
  end

  if offset == 0 then
    -- checks if its a valid date
    M.extract_day_month_year(start_day)
    return start_day
  end

  local day, month, year = M.extract_day_month_year(start_day)
  -- construct a timestamp at midnight UTC of that day
  local ts = os.time({ year = year, month = month, day = day, hour = 0 })
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
function M.convert_day_str_to_timestamp(day_month_year_str, end_of_day)
  local day, month, year = M.extract_day_month_year(day_month_year_str)
  -- bump to next day when end_of_day is requested
  local ts = os.time({
    year = year,
    month = month,
    day = day + (end_of_day and 1 or 0),
    hour = 0,
    min = 0,
    sec = 0,
  })
  -- if end_of_day, subtract 1s to get last second of the requested day
  return end_of_day and (ts - 1) or ts
end

---@param n_days integer
---@param start_day string 'DD.MM.YYYY'
---@param end_day string 'DD.MM.YYYY'
---@param canonical_today_str string 'DD.MM.YYYY'
---@param show_date_period boolean
---@param show_time boolean
---@param time_period_str? string
---@param time_period_str_singular? string
---@return string
function M.get_time_period_str_days(
  n_days,
  start_day,
  end_day,
  canonical_today_str,
  show_date_period,
  show_time,
  time_period_str,
  time_period_str_singular
)
  local is_singular = n_days == 1
  local ends_today = end_day == canonical_today_str

  if ends_today then
    local template = is_singular and time_period_str_singular or time_period_str
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

return M
