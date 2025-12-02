local M = {}

---Returns seconds as a formatted time string
---@param seconds integer Seconds
---@param max_hours? boolean Should the maximal unit be hours (default true)
---@param min_hours? boolean Should the minimal unit be hours (default false)
---@param round_hours_ge_x? integer Should hours above X be rounded (no rounding by default)
---@return string
function M.format_time(seconds, max_hours, min_hours, round_hours_ge_x)
  max_hours = (max_hours == nil) and true or max_hours

  if seconds <= 0 then
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
      local res = ('%.1fh'):format(math.max(0.1, seconds / 3600))
      local ret, _ = res:gsub('%.0h$', 'h')
      return ret
    end
    return ('%dm'):format(seconds / 60)
  end

  if max_hours or seconds < 86400 then
    local n_hours = seconds / 3600
    if round_hours_ge_x and n_hours >= round_hours_ge_x then
      return ('%dh'):format(math.floor(n_hours + 0.5))
    end
    return ('%.1fh'):format(n_hours)
  end

  local n_days = math.floor(seconds / 86400 + 0.5)
  if n_days == 1 then
    return '1 day'
  end
  return ('%d days'):format(n_days)
end

---@param start_ts integer
---@param end_ts integer
---@retrun string
function M.get_time_period_str(start_ts, end_ts)
  if end_ts <= start_ts then
    return ''
  end

  local total_seconds = end_ts - start_ts
  local total_days = math.floor(total_seconds / 86400)

  local years = math.floor(total_days / 365)
  local days = total_days - years * 365

  local months = math.floor(days / 30)
  days = days - months * 30

  local parts = {}
  if years > 0 then
    table.insert(parts, years .. ' year' .. (years > 1 and 's' or ''))
  end
  if months > 0 then
    table.insert(parts, months .. ' month' .. (months > 1 and 's' or ''))
  end
  if days > 0 or #parts == 0 then
    table.insert(parts, days .. ' day' .. (days > 1 and 's' or ''))
  end

  table.insert(parts, '(' .. total_days .. ' day' .. (days > 1 and 's' or '') .. ')')

  return table.concat(parts, ' ')
end

return M
