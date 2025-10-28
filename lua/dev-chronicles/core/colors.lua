local M = {}

local DefaultColors = require('dev-chronicles.core.enums').DefaultColors

M._namespace = vim.api.nvim_create_namespace('dev-chronicles')

---@type table<string, chronicles.Options.HighlightDefinitions.Definition>
M._lazy_standin_colors = {}

---@type string[]
M._lazy_standin_colors_keys = {}

---@type table<string, boolean>
M._highlights_cache = {}

---@param default_highlights chronicles.Options.HighlightDefinitions
function M.setup_colors(default_highlights)
  local default_project_colors_definitions = {
    { 'DevChroniclesRed', { fg = '#ff6b6b', bold = true } },
    { 'DevChroniclesBlue', { fg = '#5f91fd', bold = true } },
    { 'DevChroniclesGreen', { fg = '#95e1d3', bold = true } },
    { 'DevChroniclesYellow', { fg = '#f9ca24', bold = true } },
    { 'DevChroniclesMagenta', { fg = '#8b008b', bold = true } },
    { 'DevChroniclesPurple', { fg = '#6c5ce7', bold = true } },
    { 'DevChroniclesOrange', { fg = '#ffa500', bold = true } },
    { 'DevChroniclesLightPurple', { fg = '#a29bfe', bold = true } },
  }

  -- Preserve the order of colors
  local tbl_idx = 0
  for _, entry in ipairs(default_project_colors_definitions) do
    local name, opts = entry[1], entry[2]
    tbl_idx = tbl_idx + 1
    M._lazy_standin_colors[name] = opts
    M._lazy_standin_colors_keys[tbl_idx] = name
  end

  for hl_name, hl_opts in pairs(default_highlights) do
    vim.api.nvim_set_hl(0, hl_name, hl_opts)
  end
end

---@param random_bars_coloring boolean
---@param projects_sorted_ascending boolean
---@param n_projects integer
---@return fun(project_color?: string): string
function M.closure_get_project_color(random_bars_coloring, projects_sorted_ascending, n_projects)
  local shuffle = require('dev-chronicles.utils').shuffle

  local color_keys = M._lazy_standin_colors_keys
  local n_colors = #color_keys
  local color_index = 1

  if random_bars_coloring then
    shuffle(color_keys)
  end

  ---@param project_color string?
  ---@return string
  return function(project_color)
    if project_color then
      return M.get_or_create_hex_highlight(project_color)
    end

    local hl_name
    if random_bars_coloring then
      -- All colors were used
      if color_index > n_colors then
        shuffle(color_keys)
        color_index = 1
      end
      hl_name = color_keys[color_index]
    else
      -- Sequential color cycling
      hl_name = projects_sorted_ascending
          and color_keys[((n_projects - color_index) % n_colors) + 1]
        or color_keys[((color_index - 1) % n_colors) + 1]
    end

    color_index = color_index + 1

    return M.get_or_create_standin_highlight(hl_name)
  end
end

---@param hex_color string
---@return string
function M.get_or_create_hex_highlight(hex_color)
  local normalized = M.check_and_normalize_hex_color(hex_color)
  if not normalized then
    return DefaultColors.DevChroniclesBackupColor
  end

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
function M.get_or_create_standin_highlight(hl_name)
  if M._highlights_cache[hl_name] then
    return hl_name
  end

  local color_specs = M._lazy_standin_colors[hl_name]
  if not color_specs then
    return DefaultColors.DevChroniclesBackupColor
  end

  vim.api.nvim_set_hl(0, hl_name, color_specs)
  M._highlights_cache[hl_name] = true

  return hl_name
end

---@param buf integer
---@param hl_name string
---@param line_idx integer
---@param col integer
---@param end_col integer
function M.apply_highlight(buf, hl_name, line_idx, col, end_col)
  hl_name = M.get_or_create_standin_highlight(hl_name)
  vim.api.nvim_buf_add_highlight(buf, M._namespace, hl_name, line_idx, col, end_col)
end

---@param buf integer
---@param hex string
---@param line_idx integer
---@param col integer
---@param end_col integer
function M.apply_highlight_hex(buf, hex, line_idx, col, end_col)
  local hl_name = M.get_or_create_hex_highlight(hex)
  vim.api.nvim_buf_add_highlight(buf, M._namespace, hl_name, line_idx, col, end_col)
end

---@param buf integer
---@param highlights chronicles.Highlight
function M.apply_highlights(buf, highlights)
  local ns = M._namespace
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(
      buf,
      ns,
      hl.hl_group,
      hl.line - 1,
      hl.col,
      hl.end_col == -1 and -1 or hl.end_col
    )
  end
end

---@param hex string
---@return string?
function M.check_and_normalize_hex_color(hex)
  local h = hex
    and hex
      :gsub('%s+', '')
      :match('^#?([%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F])$')
  return h and h:lower()
end

return M
