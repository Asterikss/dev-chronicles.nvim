local M = {}

---Accepts a year string in format 'YYYY' and transforms it into a unix timestamp.
---If `end_of_year` is true, returns the last possible timestamp within that year.
---@param year_str string Year in format: 'YYYY'
---@param end_of_year? boolean Should the end of year timestamp be returned
---@return integer: timestamp
function M.convert_year_str_to_timestamp(year_str, end_of_year)
  local year = assert(tonumber(year_str), 'invalid year string')
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

return M
