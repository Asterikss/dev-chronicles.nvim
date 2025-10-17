local M = {}

---Return seconds as a formatted time string
---@param seconds integer Seconds
---@param max_hours? boolean Should the maximal unit be hours (default true)
---@param min_hours? boolean Should the minimal unit be hours (default false)
---@param round_hours_ge_x? integer Should hours above X be rounded (no rounding by default)
---@return string
function M.format_time(seconds, max_hours, min_hours, round_hours_ge_x)
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
    local n_hours = seconds / 3600
    if round_hours_ge_x and n_hours >= round_hours_ge_x then
      return ('%dh'):format(math.floor(n_hours + 0.5))
    end
    return ('%.1fh'):format(seconds / 3600)
  end

  local n_days = math.floor(seconds / 86400 + 0.5)
  if n_days == 1 then
    return '1 day'
  end
  return ('%d days'):format(n_days)
end

return M
