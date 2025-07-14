---@meta

---@alias DashboardType
---| 'Default'
---| 'Custom'
---| 'All'

---@alias chronicles.BarLevel
---| 'Header'
---| 'Body'
---| 'Footer'

---@class (exact) chronicles.Dashboard.Stats.ParsedProjectData
---@field total_time integer
---@field last_worked integer
---@field total_global_time integer?

---@alias chronicles.Dashboard.Stats.ParsedProjects table<string, chronicles.Dashboard.Stats.ParsedProjectData>

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
---@field global_time integer?

---@class (exact) ProjectData
---@field total_time number
---@field by_month table<string, number>
---@field first_worked number
---@field last_worked number

---@alias Projects table<string, ProjectData>

---@class (exact) ChroniclesData
---@field global_time number
---@field tracking_start number
---@field projects Projects

---@class (exact) chronicles.BarLevelRepresentation
---@field realized_rows string[]
---@field row_codepoint_counts integer[]
---@field char_display_widths integer[][]

---@class (exact) chronicles.BarRepresentation
---@field header chronicles.BarLevelRepresentation
---@field body chronicles.BarLevelRepresentation
---@field footer chronicles.BarLevelRepresentation
