local M = {}

local notify = require('dev-chronicles.utils.notify')

---@param file_path string
---@return chronicles.ChroniclesData?
function M.load_data(file_path)
  if vim.fn.filereadable(file_path) == 0 then
    local current_timestamp = os.time()
    ---@type chronicles.ChroniclesData
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
    notify.error('Failed loading data from disk: Failed to read the data file')
    return
  end

  local ok_decode, data = pcall(vim.fn.json_decode, table.concat(content, '\n'))
  if not ok_decode then
    notify.error('Failed loading data from disk: Could not decode json')
    return
  end

  return data
end

---@param data chronicles.ChroniclesData
---@param file_path string
function M.save_data(data, file_path)
  local json_content = vim.fn.json_encode(data)

  -- Write to temp file first, then rename for atomic operation
  local temp_file = file_path .. '.tmp'
  local ok = pcall(vim.fn.writefile, { json_content }, temp_file)

  if ok then
    vim.fn.rename(temp_file, file_path)
  else
    notify.error('Failed to write the data to disk')
  end
end

return M
