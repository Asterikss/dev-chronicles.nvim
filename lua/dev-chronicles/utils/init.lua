local M = {}

M.expand = function(path)
  local expanded = vim.fn.expand(path)
  if expanded:sub(-1) ~= '/' then
    return expanded .. '/'
  end
  return expanded
end

---If the `path` contains the home directory, replace it with `~`
---@param path string
---@return string
M.unexpand = function(path)
  local home = vim.loop.os_homedir()
  if path:sub(1, #home) == home then
    return '~' .. path:sub(#home + 1)
  else
    return path
  end
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
