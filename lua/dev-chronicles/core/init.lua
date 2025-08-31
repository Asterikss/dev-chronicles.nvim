local M = {}

---@param opts chronicles.Options
function M.init(opts)
  math.randomseed(os.time())
  require('dev-chronicles.core.highlights').setup_highlights()
  require('dev-chronicles.core.commands').setup_commands(opts)
end

---Returns the id of the project if the supplied cwd should be tracked,
---otherwise nil. Assumes all paths are absolute and expanded, and all dirs end
---with a slash.
---@param cwd string
---@param tracked_parent_dirs string[]
---@param tracked_dirs string[]
---@param exclude_dirs_absolute string[]
---@param parsed_exclude_subdirs_relative_map table<string, boolean>
---@param differentiate_projects_by_folder_not_path boolean
---@return string?, string?
function M.is_project(
  cwd,
  tracked_parent_dirs,
  tracked_dirs,
  exclude_dirs_absolute,
  parsed_exclude_subdirs_relative_map,
  differentiate_projects_by_folder_not_path
)
  local unexpand = require('dev-chronicles.utils').unexpand
  local get_project_name = require('dev-chronicles.utils.strings').get_project_name

  if not cwd:match('/$') then
    cwd = cwd .. '/'
  end

  -- Because both end with a slash, if it matches, it cannot be a different dir with
  -- the same prefix
  for _, exclude_path in ipairs(exclude_dirs_absolute) do
    if cwd:find(exclude_path, 1, true) == 1 then
      return
    end
  end

  for _, dir in ipairs(tracked_dirs) do
    if cwd == dir then
      local project_name = get_project_name(cwd)
      return (differentiate_projects_by_folder_not_path and project_name or unexpand(cwd)),
        project_name
    end
  end

  -- only subdirectories are matched
  for _, parent_dir in ipairs(tracked_parent_dirs) do
    if cwd == parent_dir then
      return
    end
  end

  for _, parent_dir in ipairs(tracked_parent_dirs) do
    if cwd:find(parent_dir, 1, true) == 1 then
      -- Get the first directory after the parent_dir
      local first_dir = cwd:sub(#parent_dir):match('([^/]+)')
      if first_dir then
        if parsed_exclude_subdirs_relative_map[first_dir] then
          return
        end

        local project_id = parent_dir .. first_dir .. '/'
        return (differentiate_projects_by_folder_not_path and first_dir or unexpand(project_id)),
          first_dir
      end
    end
  end
end

return M
