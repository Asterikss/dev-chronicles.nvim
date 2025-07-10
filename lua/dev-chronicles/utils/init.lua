local M = {}

---@class ProjectData
---@field total_time number
---@field by_month table<string, number>
---@field first_worked number
---@field last_worked number

---@alias Projects table<string, ProjectData>

---@class ChroniclesData
---@field global_time number
---@field tracking_start number
---@field projects Projects

M.expand = function(path)
  local expanded = vim.fn.expand(path)
  if expanded ~= '/' and expanded:sub(-1) ~= '/' then
    expanded = expanded .. '/'
  end
  return expanded
end

M.unexpand = function(path)
  local home = vim.loop.os_homedir()
  if path:sub(1, #home) == home then
    return '~' .. path:sub(#home + 1)
  else
    return path
  end
end

---@return ChroniclesData | nil
M.load_data = function()
  local file_path = require('dev-chronicles.config').options.data_file

  if vim.fn.filereadable(file_path) == 0 then
    return {
      global_time = 0,
      tracking_start = M.get_current_timestamp(),
      projects = {},
    }
  end

  local ok, content = pcall(vim.fn.readfile, file_path)
  if not ok then
    local err = 'Error loading data from disk: Failed to read the data file'
    vim.notify('DevChronicles: ' .. err)
    local f = io.open(require('dev-chronicles.config').options.log_file, 'a')
    if f then
      f:write(err)
      f:close()
    end
    return nil
  end

  local ok_decode, data = pcall(vim.fn.json_decode, table.concat(content, '\n'))
  if not ok_decode then
    local err = 'Error loading data from disk: Could not decode json'
    vim.notify('DevChronicles: ' .. err)
    local f = io.open(require('dev-chronicles.config').options.log_file, 'a')
    if f then
      f:write(err)
      f:close()
    end
    return nil
  end

  return data
end

---Save Chronicles data
---@param data ChroniclesData
M.save_data = function(data)
  local data_file = require('dev-chronicles.config').options.data_file
  local json_content = vim.fn.json_encode(data)

  -- Write to temp file first, then rename for atomic operation
  local temp_file = data_file .. '.tmp'
  local ok = pcall(vim.fn.writefile, { json_content }, temp_file)

  if ok then
    vim.fn.rename(temp_file, data_file)
  end
end

---Returns current unix timestamp
---@return integer
M.get_current_timestamp = function()
  return os.time()
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

---Accepts a month-year string in format: 'MM.YYYY' and extracts month
---and year from it, turning them to integers.
---@param month_year_str string Date in format: 'MM.YYYY'
---@return integer, integer: month, year
M.extract_month_year = function(month_year_str)
  local month, year = month_year_str:match('(%d%d)%.(%d%d%d%d)')
  month = tonumber(month)
  year = tonumber(year)
  if not month or not year then
    error('Invalid month or year: ' .. tostring(month_year_str))
  end
  return month, year
end

---Returns the previous month to `start_month` as a string. Both formated as:
---'MM.YYYY'. Offset can be passed to change how many months back to go
---(default 1).
---@param start_month string From which month to offset ('MM.YYYY')
---@param offset? integer How many months back to go (default 1)
---@return string
M.get_previous_month = function(start_month, offset)
  offset = offset or 1
  if offset < 0 then
    vim.notify('Offset, when getting previous month, cannot be smaller than 0')
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
---unix timestamp. If `last_of_month` is true, returns the last possible timestamp
---within that month.
---@param month_year_str string Date in format: 'MM.YYYY'
---@param end_of_month? boolean Should the end of month timestamp be returned
---@return integer unix timestamp
M.convert_month_str_to_timestamp = function(month_year_str, end_of_month)
  local month, year = M.extract_month_year(month_year_str)
  if end_of_month then
    -- Get the first day of the next month, then subtract one second
    local next_month = month + 1
    local next_year = year
    if next_month > 12 then
      next_month = 1
      next_year = year + 1
    end
    return os.time({
      year = next_year,
      month = next_month,
      day = 1,
      hour = 0,
      min = 0,
      sec = 0,
    }) - 1
  end
  return os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 })
end

---Return seconds as a formatted string
---@param seconds integer Seconds
---@param max_hours? boolean Should the maximal unit be hours (default true)
---@return string
M.format_time = function(seconds, max_hours)
  if max_hours == nil then
    max_hours = true
  end
  if seconds < 60 then
    return string.format('%ds', seconds)
  end
  if seconds < 3600 then
    return string.format('%.1fm', seconds / 60)
  end
  if max_hours or seconds < 86400 then
    return string.format('%.1fh', seconds / 3600)
  end
  return string.format('%d days', seconds / 86400)
end

---Format the time period between `start_month_year` and `end_month_year`. If
---`end_month_year` is the current month, the period ends at the current date
---and time.
---The result is formatted as:
---  - 'MM-MM.YYYY (duration)' if both months are in the same year
---  - 'MM.YYYY-MM.YYYY (duration)' if the months are in different years
---where 'duration' is the time between the two dates, formatted as s/m/h/d.
---@param start_month_year string 'MM.YYYY'
---@param end_month_year string 'MM.YYYY'
---@return string: Formatted period string
M.get_time_period_str = function(start_month_year, end_month_year)
  local start_month_timestamp = M.convert_month_str_to_timestamp(start_month_year)

  local end_month_timestamp
  if M.get_month_str() == end_month_year then
    end_month_timestamp = M.get_current_timestamp()
  else
    end_month_timestamp = M.convert_month_str_to_timestamp(end_month_year, true)
  end

  local time_period_str = M.format_time(end_month_timestamp - start_month_timestamp, false)
  time_period_str = ' (' .. time_period_str .. ')'

  local _, start_year = M.extract_month_year(start_month_year)
  local _, end_year = M.extract_month_year(end_month_year)

  if start_year == end_year then
    return string.sub(start_month_year, 1, 2)
      .. '-'
      .. string.sub(end_month_year, 1, 2)
      .. '.'
      .. start_year
      .. time_period_str
  end
  return start_month_year .. '-' .. end_month_year .. time_period_str
end

---@generic T
---@param table T[]
---@return T
M.get_random_from_tbl = function(table)
  return table[math.random(1, #table)]
end

---Shuffles a table in-place
---@param tbl table[]
M.shuffle = function(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
end

return M
