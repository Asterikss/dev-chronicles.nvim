local M = {}

function M.make_timeline_section(opts)
  ---@type chronicles.Options.Timeline.Section
  local timeline_section_opts = {
    bar_width = 4,
    bar_spacing = 1,
    row_repr = nil,
    n_by_default = 30,
    window_height = 0.85,
    window_width = 0.99,
    header = {
      total_time = {
        as_hours_max = true,
        as_hours_min = true,
        round_hours_ge_x = 1,
        format_str = 'total time: %s',
      },
      period_indicator = {
        date_range = true,
        days_count = true,
        time_period_str = 'last %s days',
        time_period_str_singular = 'today',
      },
      show_current_session_time = true,
      window_title = ' Dev Chronicles Timeline ',
      project_prefix = '  ',
    },
    segment_time_labels = {
      as_hours_max = true,
      as_hours_min = true,
      round_hours_ge_x = 1,
      color = nil,
      color_like_top_segment_project = true,
      hide_when_empty = false,
    },
    segment_numeric_labels = {
      enable = true,
      color = nil,
      color_like_top_segment_project = true,
      hide_when_empty = false,
    },
    segment_abbr_labels = {
      enable = true,
      color = nil,
      color_like_top_segment_project = true,
      hide_when_empty = false,
      locale = nil,
      date_abbrs = nil,
    },
  }

  return vim.tbl_deep_extend('force', timeline_section_opts, opts or {})
end

return M
