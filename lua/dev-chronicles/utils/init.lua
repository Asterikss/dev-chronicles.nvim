local M = {}

---@class ProjectData
---@field total_time number
---@field by_month table<string, number>
---@field first_worked number
---@field last_worked number

---@class Projects
---@field [string] ProjectData

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

M.is_project = function(cwd)
  -- assumes all paths are absolute and expanded, and all dirs end with a slash
  local options = require('dev-chronicles.config').options
  -- TODO: probably start from longest so that nested projects are treated correctly
  for _, tracked_path in ipairs(options.tracked_dirs) do
    -- No exact matches. Only subdirectories are matched.
    if
      cwd:find(tracked_path, 1, true) == 1
      and #cwd > #tracked_path
      and cwd:sub(#tracked_path, #tracked_path) == '/'
    then
      -- Get the first directory after tracked_path
      local first_dir = cwd:sub(#tracked_path):match('([^/]+)')
      if first_dir then
        local project_id = tracked_path .. first_dir .. '/'
        return true, M.unexpand(project_id)
      end
    end
  end

  return false, nil
end

---@return ChroniclesData | nil
M.load_data = function()
  local file_path = require('dev-chronicles.config').options.data_file

  if vim.fn.filereadable(file_path) == 0 then
    return {
      global_time = 0,
      tracking_start = M.current_timestamp(),
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
M.current_timestamp = function()
  return os.time()
end

---Returns the current month as a string in this format: 'MM.YYYY'
---@return string
M.get_current_month = function()
  return tostring(os.date('%m.%Y'))
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
---unix timestamp
---@param month_year_str string Date in format: 'MM.YYYY'
---@return integer unix timestamp
M.convert_month_str_to_timestamp = function(month_year_str)
  local month, year = M.extract_month_year(month_year_str)
  return os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 })
end

return M
