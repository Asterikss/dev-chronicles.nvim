---@meta

---@alias chronicles.Panel.Type
---| 'Dashboard'
---| 'Timeline'
---| 'Stats'
---| 'All'

---@alias chronicles.Panel.Subtype
---| 'Days'
---| 'Months'
---| 'Years'
---| 'All'

---@alias chronicles.BarLevel
---| 'Header'
---| 'Body'
---| 'Footer'

---@class chronicles.SessionState
---@field project_id? string
---@field project_name? string
---@field start_time? integer
---@field is_tracking boolean

---@class chronicles.SessionBase
---@field canonical_ts integer
---@field canonical_today_str string
---@field canonical_month_str string
---@field canonical_year_str string
---@field now_ts integer

---@class chronicles.SessionActive
---@field project_id string
---@field project_name string
---@field start_time integer
---@field session_time_seconds integer

---@class (exact) chronicles.Panel.Subtype.Args
---@field start_offset? integer
---@field end_offset? integer
---@field start_date? string
---@field end_date? string

---@class (exact) chronicles.Dashboard.Stats.ParsedProjectData
---@field total_time integer
---@field first_worked integer
---@field last_worked integer
---@field last_worked_canonical integer
---@field tags_map table<string, any>
---@field total_global_time integer?

---@alias chronicles.Dashboard.Stats.ParsedProjects table<string, chronicles.Dashboard.Stats.ParsedProjectData>

---@class (exact) chronicles.Dashboard.Data
---@field global_time integer
---@field global_time_filtered integer
---@field projects_filtered_parsed? chronicles.Dashboard.Stats.ParsedProjects
---@field does_include_curr_date boolean
---@field time_period_str string

---@class (exact) chronicles.Dashboard.Stats
---@field global_time integer
---@field global_time_filtered integer
---@field projects_filtered_parsed chronicles.Dashboard.Stats.ParsedProjects
---@field start_date string
---@field end_date string

---@class (exact) chronicles.Dashboard.BarData
---@field project_name_tbl string[]
---@field project_time integer
---@field height  integer
---@field color string
---@field start_col integer
---@field width integer
---@field current_bar_level chronicles.BarLevel
---@field curr_bar_representation_index integer
---@field global_project_time integer?

---@class (exact) chronicles.Dashboard.FinalProjectData
---@field id string
---@field time integer
---@field last_worked integer
---@field last_worked_canonical integer
---@field global_time integer?

---@class (exact) chronicles.ChroniclesData.ProjectData
---@field total_time integer
---@field by_year table<string, {by_month: table<string, number>, total_time: integer}>
---@field by_day table<string, number>
---@field first_worked integer
---@field last_worked integer
---@field last_worked_canonical integer
---@field tags_map table<string, any>

---@class (exact) chronicles.ChroniclesData
---@field global_time integer
---@field tracking_start integer
---@field last_data_write integer
---@field schema_version integer
---@field projects table<string, chronicles.ChroniclesData.ProjectData>

---@class (exact) chronicles.BarLevelRepresentation
---@field realized_rows string[]
---@field row_codepoint_counts integer[]
---@field char_display_widths integer[][]

---@class (exact) chronicles.BarRepresentation
---@field header chronicles.BarLevelRepresentation
---@field body chronicles.BarLevelRepresentation
---@field footer chronicles.BarLevelRepresentation

---@alias chronicles.Dashboard.TopProjectsArray (string|boolean)[]

---@class chronicles.WindowDimensions
---@field width integer
---@field height integer
---@field row integer
---@field col integer

---@class chronicles.Panel.Data
---@field lines string[]
---@field highlights chronicles.Highlight
---@field window_dimensions chronicles.WindowDimensions
---@field window_title? string
---@field window_border? string[]

---@class chronicles.Highlight
---@field line integer
---@field col integer
---@field end_col integer
---@field hl_group string

-- --------------------------------------------
-- Plugin Configuration Types
-- --------------------------------------------

---@class chronicles.Options.DefaultVars
---@field bar_width integer
---@field bar_header_extends_by integer
---@field bar_footer_extends_by integer
---@field bar_spacing integer

---@class chronicles.Options.Dashboard.Header.TopProjects
---@field enable boolean
---@field extra_space_between_bars boolean
---@field use_wide_bars boolean
---@field min_top_projects_len_to_show integer

---@class chronicles.Options.Dashboard.Header
---@field show_date_period boolean
---@field show_time boolean
---@field time_period_str string?
---@field time_period_singular_str string?
---@field total_time_as_hours_max boolean
---@field total_time_as_hours_min boolean
---@field total_time_round_hours_above_one boolean
---@field show_current_session_time boolean
---@field show_global_time_for_each_project boolean
---@field show_global_time_only_if_differs boolean
---@field proj_global_total_time_round_hours_above_one boolean
---@field color_global_proj_times_like_bars boolean
---@field total_time_format_str string
---@field prettify boolean
---@field window_title string
---@field top_projects chronicles.Options.Dashboard.Header.TopProjects

---@class chronicles.Options.Dashboard.Sorting
---@field enable boolean
---@field sort_by_last_worked_not_total_time boolean
---@field ascending boolean

---@class chronicles.Options.Dashboard.Base
---@field header chronicles.Options.Dashboard.Header
---@field sorting chronicles.Options.Dashboard.Sorting
---@field dynamic_bar_height_thresholds any?
---@field n_by_default integer
---@field proj_total_time_as_hours_max boolean
---@field proj_total_time_as_hours_min boolean
---@field proj_total_time_round_hours_above_one boolean
---@field random_bars_coloring boolean
---@field bars_coloring_follows_sorting_in_order boolean
---@field color_proj_times_like_bars boolean
---@field min_proj_time_to_display_proj integer
---@field window_height number
---@field window_width number
---@field window_border? string[]
---@field bar_chars any?

---@class chronicles.Options.Dashboard.Section : chronicles.Options.Dashboard.Base
---@field header chronicles.Options.Dashboard.Header
---@field sorting chronicles.Options.Dashboard.Sorting

---@class chronicles.Options.Dashboard.Footer
---@field let_proj_names_extend_bars_by_one boolean

---@class chronicles.Options.Dashboard
---@field bar_width integer width of each column
---@field bar_header_extends_by integer
---@field bar_footer_extends_by integer
---@field bar_spacing integer spacing between each column
---@field bar_chars string[][][] All the bar representation patterns
---@field use_extra_default_dashboard_bar_chars boolean
---@field footer chronicles.Options.Dashboard.Footer
---@field dashboard_days chronicles.Options.Dashboard.Section
---@field dashboard_months chronicles.Options.Dashboard.Section
---@field dashboard_all chronicles.Options.Dashboard.Section

---@class chronicles.Options
---@field tracked_parent_dirs string[] List of parent dirs to track
---@field tracked_dirs string[] List of dir paths to track
---@field exclude_subdirs_relative string[] List of subdirs to exclude from tracked_parent_dirs subdirs
---@field exclude_dirs_absolute string[] List of absolute dirs to exclude (tracked_parent_dirs can have two different dirs that have two subdirs of the same name)
---@field sort_tracked_parent_dirs boolean If paths are not supplied from longest to shortest, then they need to be sorted like that
---@field differentiate_projects_by_folder_not_path boolean
---@field min_session_time integer Minimum session time in seconds
---@field track_days boolean
---@field extend_today_to_4am boolean
---@field dashboard chronicles.Options.Dashboard
---@field highlights table<string, { fg?: string, bg?: string, bold?: boolean, italic?: boolean, underline?: boolean }>
---@field data_file string Path to the data file
---@field log_file string Path to the log file
---@field for_dev_start_time? integer
---@field parsed_exclude_subdirs_relative_map? table<string, boolean> exclude_subdirs_relative as a map
---@field extra_default_dashboard_bar_chars string[][][]
