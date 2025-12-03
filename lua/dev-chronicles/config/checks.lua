local M = {}

local notify = require('dev-chronicles.utils.notify')

---@param opts chronicles.Options
---@return boolean
function M.check_opts(opts)
  if opts.dashboard.dashboard_months.n_by_default < 1 then
    notify.error('n_months_by_default should be greter than 0')
    return false
  end

  if opts.dashboard.bar_spacing < 0 then
    notify.error('bar_spacing should be a positive number')
    return false
  end

  if opts.dashboard.footer.let_proj_names_extend_bars_by_one and opts.dashboard.bar_spacing < 2 then
    notify.error(
      'if let_proj_names_extend_bars_by_one is set to true then bar_spacing should be at least 2'
    )
    return false
  end

  if opts.dashboard.bar_header_extends_by * 2 > opts.dashboard.bar_spacing then
    notify.error('dashboard.bar_header_extends_by extends too much given dashboard.bar_spacing')
    return false
  end
  if opts.dashboard.bar_footer_extends_by * 2 > opts.dashboard.bar_spacing then
    notify.error('dashboard.bar_footer_extends_by extends too much given dashboard.bar_spacing')
    return false
  end

  if opts.track_days.optimize_storage_for_x_days then
    if opts.track_days.optimize_storage_for_x_days <= 0 then
      notify.error('optimize_storage_for_x_days should be greater than 0')
      return false
    end
    if opts.dashboard.dashboard_days.n_by_default > opts.track_days.optimize_storage_for_x_days then
      notify.error(
        'dashboard.dashboard_days.n_by_default is greater than track_days.optimize_storage_for_x_days. Cannot show older days than previous optimize_storage_for_x_days days. Setting it to the limit'
      )
      opts.dashboard.dashboard_days.n_by_default = opts.track_days.optimize_storage_for_x_days
    end
  end

  return true
end

return M
