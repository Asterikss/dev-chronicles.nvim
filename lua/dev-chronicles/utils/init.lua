local M = {}

M.get_data_file_path = function()
  return require('dev-chronicles.config').data_path
end

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
  local config = require('dev-chronicles.config')
  -- TODO: probably start from longest so that nested projects are treated correctly
  for _, tracked_path in ipairs(config.options.tracked_paths) do
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

M.load_data = function()
  local file_path = M.get_data_file_path()

  if vim.fn.filereadable(file_path) == 0 then
    return {
      global_time = 0,
      tracking_start = M.current_timestamp(),
      projects = {},
    }
  end

  local ok, content = pcall(vim.fn.readfile, file_path)
  if not ok then
    return 'Failed to read data file'
  end

  local ok_decode, data = pcall(vim.fn.json_decode, table.concat(content, '\n'))
  if not ok_decode then
    return 'Could not decode json data'
  end

  return data
end

M.save_data = function(data)
  local file_path = M.get_data_file_path()
  local json_content = vim.fn.json_encode(data)

  -- Write to temp file first, then rename for atomic operation
  local temp_file = file_path .. '.tmp'
  local ok = pcall(vim.fn.writefile, { json_content }, temp_file)

  if ok then
    vim.fn.rename(temp_file, file_path)
  end
end

function M.current_timestamp()
  return os.time()
end

function M.get_current_month()
  return os.date('%m.%Y')
end

return M
