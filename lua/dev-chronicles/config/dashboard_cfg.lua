local M = {}

---@type chronicles.Options.Dashboard.DefaultVars
M.default_dashboard_vars = {
  bar_width = 9,
  bar_header_extends_by = 1,
  bar_footer_extends_by = 1,
  bar_spacing = 3,
}

function M.make_dashboard_section(opts)
  ---@type chronicles.Options.Dashboard.Section
  local dashboard_section_opts = {
    header = {
      period_indicator = {
        date_range = true,
        days_count = true,
        time_period_str = nil,
        time_period_str_singular = nil,
      },
      show_current_session_time = true,
      prettify = true,
      window_title = ' Dev Chronicles ',
      total_time = {
        as_hours_max = true,
        as_hours_min = true,
        round_hours_ge_x = 1,
        format_str = 'total time: %s',
      },
      project_global_time = {
        enable = true,
        show_only_if_differs = true,
        color_like_bars = false,
        as_hours_max = true,
        as_hours_min = true,
        round_hours_ge_x = 1,
      },
      top_projects = {
        enable = true,
        extra_space_between_bars = false,
        wide_bars = false,
        super_extra_duper_wide_bars = false,
        min_top_projects_len_to_show = 1,
      },
    },
    sorting = {
      enable = true,
      sort_by_last_worked_not_total_time = true,
      ascending = true,
    },
    dynamic_bar_height_thresholds = nil,
    n_by_default = 2,
    random_bars_coloring = false,
    bars_coloring_follows_sorting_in_order = true,
    min_proj_time_to_display_proj = 0,
    window_height = 0.8,
    window_width = 0.8,
    window_border = nil,
    bar_repr_list = nil,
    project_total_time = {
      as_hours_max = true,
      as_hours_min = true,
      round_hours_ge_x = 1,
      color_like_bars = false,
    },
  }

  return vim.tbl_deep_extend('force', dashboard_section_opts, opts or {})
end

return M
