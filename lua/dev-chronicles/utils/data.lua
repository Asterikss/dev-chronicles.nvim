local M = {}

---@param file_path string
---@return chronicles.ChroniclesData?
M.load_data = function(file_path)
  if vim.fn.filereadable(file_path) == 0 then
    local current_timestamp = os.time() -- TODO: propagate from session info
    return {
      global_time = 0,
      tracking_start = current_timestamp,
      last_data_write = current_timestamp,
      schema_version = 1,
      projects = {},
    }
  end

  local ok, content = pcall(vim.fn.readfile, file_path)
  if not ok then
    local err = 'DevChronicles Error: failed loading data from disk: Failed to read the data file'
    vim.notify(err)
    local f = io.open(require('dev-chronicles.config').get_opts().log_file, 'a')
    if f then
      f:write(err)
      f:close()
    end
    return nil
  end

  local ok_decode, data = pcall(vim.fn.json_decode, table.concat(content, '\n'))
  if not ok_decode then
    local err = 'DevChronicles Error: failed loading data from disk: Could not decode json'
    vim.notify(err)
    local f = io.open(require('dev-chronicles.config').get_opts().log_file, 'a')
    if f then
      f:write(err)
      f:close()
    end
    return nil
  end

  return data
end

---@param data chronicles.ChroniclesData
---@param file_path string
M.save_data = function(data, file_path)
  local json_content = vim.fn.json_encode(data)

  -- Write to temp file first, then rename for atomic operation
  local temp_file = file_path .. '.tmp'
  local ok = pcall(vim.fn.writefile, { json_content }, temp_file)

  if ok then
    vim.fn.rename(temp_file, file_path)
  end
end

return M
