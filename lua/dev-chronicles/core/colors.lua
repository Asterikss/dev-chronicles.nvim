local M = {}

---@type table<string, {fg: string, bold: boolean}>
M._default_project_colors = {}

---@type string[]
M._default_project_colors_keys = {}

---@type table<string, boolean>
M._highlights_cache = {}

---@param default_highlights table<string, { fg: string, bg: string, bold: boolean, italic: boolean, underline: boolean }>
function M.setup_colors(default_highlights)
  local default_project_colors_definitions = {
    { 'DevChroniclesRed', { fg = '#ff6b6b', bold = true } },
    { 'DevChroniclesBlue', { fg = '#5F91FD', bold = true } },
    { 'DevChroniclesGreen', { fg = '#95e1d3', bold = true } },
    { 'DevChroniclesYellow', { fg = '#f9ca24', bold = true } },
    { 'DevChroniclesMagenta', { fg = '#8b008b', bold = true } },
    { 'DevChroniclesPurple', { fg = '#6c5ce7', bold = true } },
    { 'DevChroniclesOrange', { fg = '#ffa500', bold = true } },
    { 'DevChroniclesLightPurple', { fg = '#a29bfe', bold = true } },
    { 'DevChroniclesBackupColor', { fg = '#fff588', bold = true } },
  }

  local tbl_idx = 0
  for _, entry in ipairs(default_project_colors_definitions) do
    local name, opts = entry[1], entry[2]
    tbl_idx = tbl_idx + 1
    M._default_project_colors[name] = opts
    M._default_project_colors_keys[tbl_idx] = name
  end

  for hl_name, hl_opts in pairs(default_highlights) do
    vim.api.nvim_set_hl(0, hl_name, hl_opts)
    M._highlights_cache[hl_name] = true
  end
end

function M.closure_get_project_color(random_bars_coloring, projects_sorted_ascending, n_projects)
  local shuffle = require('dev-chronicles.utils').shuffle

  local color_keys = M._default_project_colors_keys
  local n_colors = #color_keys
  local color_index

  if random_bars_coloring then
    shuffle(color_keys)
    color_index = 1
  end

  ---@param i integer loop index
  ---@param project_color string?
  return function(i, project_color)
    if project_color then
      return M._get_or_create_highlight(project_color)
    end

    local hl_name
    if random_bars_coloring then
      -- All colors were used
      if color_index > n_colors then
        shuffle(color_keys)
        color_index = 1
      end
      hl_name = color_keys[color_index]
      color_index = color_index + 1
    else
      -- Sequential color cycling
      hl_name = projects_sorted_ascending and color_keys[((n_projects - i) % n_colors) + 1]
        or color_keys[((i - 1) % n_colors) + 1]
    end

    return M._get_or_create_default_highlight(hl_name)
  end
end

---@param hex_color string
---@return string
function M._get_or_create_highlight(hex_color)
  local normalized = hex_color:gsub('^#', ''):lower()
  local hl_name = 'DevChroniclesCustom' .. normalized:upper()

  if M._highlights_cache[hl_name] then
    return hl_name
  end

  vim.api.nvim_set_hl(0, hl_name, { fg = '#' .. normalized, bold = true })
  M._highlights_cache[hl_name] = true

  return hl_name
end

---@param hl_name string
---@return string
function M._get_or_create_default_highlight(hl_name)
  if M._highlights_cache[hl_name] then
    return hl_name
  end

  local color_specs = M._default_project_colors[hl_name]
  if not color_specs then
    hl_name = 'DevChroniclesBackupColor'
    color_specs = M._default_project_colors[hl_name]
  end

  vim.api.nvim_set_hl(0, hl_name, color_specs)
  M._highlights_cache[hl_name] = true

  return hl_name
end

return M
