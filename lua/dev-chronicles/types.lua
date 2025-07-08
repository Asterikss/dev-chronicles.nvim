---@meta

---@alias DashboardType
---| 'Default'
---| 'Custom'
---| 'All'

---@class (exact) chronicles.Dashboard.Stats.ParsedProjectsData
---@field total_time integer
---@field last_worked integer

---@alias chronicles.Dashboard.Stats.ParsedProjects table<string, chronicles.Dashboard.Stats.ParsedProjectsData>

---@class (exact) chronicles.Dashboard.Stats
---@field global_time integer
---@field global_time_filtered integer
---@field projects_filtered Projects
---@field projects_filtered_parsed chronicles.Dashboard.Stats.ParsedProjects
---@field start_date string
---@field end_date string

---@class (exact) chronicles.Dashboard.BarsData
---@field project_name_tbl table<string>
---@field project_time integer
---@field height  integer
---@field lines table
---@field color string
---@field start_col integer
---@field width integer

---@class (exact) chronicles.Dashboard.ProjectArray
---@field id string
---@field time integer
---@field last_worked  integer
