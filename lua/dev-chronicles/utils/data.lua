local M = {}

local notify = require('dev-chronicles.utils.notify')

---@type {file_path: string?, file_mtime: integer?, data: chronicles.ChroniclesData?}
local chronicles_data_cache = {
  file_path = nil,
  file_mtime = nil,
  data = nil,
}

---@param file_path string
---@return chronicles.ChroniclesData?
function M.load_data(file_path)
  local file_stat = vim.uv.fs_stat(file_path)
  local current_mtime = file_stat and file_stat.mtime.sec or 0

  if
    current_mtime == chronicles_data_cache.file_mtime
    and chronicles_data_cache.file_path == file_path
    and chronicles_data_cache.data
  then
    return chronicles_data_cache.data
  end

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

  chronicles_data_cache = {
    file_path = file_path,
    file_mtime = current_mtime,
    data = data,
  }

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
