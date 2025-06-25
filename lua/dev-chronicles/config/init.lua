local M = {}

local defaults = {
  tracked_dirs = {},
  tracked_paths = {},
  min_session_time = 180,
  n_months_default_dashboard = 2,
  data_file = 'dev-chronicles.json',
  log_file = 'log.dev-chronicles.log',
}

M.options = {}

M.setup = function(opts)
  local utils = require('dev-chronicles.utils')
  M.options = vim.tbl_deep_extend('force', defaults, opts or {})

  if type(M.options.tracked_dirs) == 'string' then
    M.options.tracked_dirs = { M.options.tracked_dirs }
  end

  for i = 1, #M.options.tracked_dirs do
    M.options.tracked_dirs[i] = utils.expand(M.options.tracked_dirs[i])
  end

  if type(M.options.tracked_paths) == 'string' then
    M.options.tracked_paths = { M.options.tracked_paths }
  end

  for i = 1, #M.options.tracked_paths do
    M.options.tracked_paths[i] = utils.expand(M.options.tracked_paths[i])
  end

  if vim.fn.isabsolutepath(M.options.data_file) == 1 then
    M.data_path = M.options.data_file
  else
    M.data_path = vim.fn.stdpath('data') .. '/' .. M.options.data_file
  end

  if vim.fn.isabsolutepath(M.options.log_file) == 1 then
    M.options.log_file = M.options.log_file
  else
    M.options.log_file = vim.fn.stdpath('data') .. '/' .. M.options.log_file
  end

  require('dev-chronicles.core').init()
end

return M
