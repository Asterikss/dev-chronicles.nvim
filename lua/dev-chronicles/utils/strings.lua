local M = {}

---Formats project name as a table of strings. The table has at most 3 parts.
---Each part’s length is at most max_width (characters, not bytes).
---@param project_name string
---@param max_width integer
---@return table<string>
function M.format_project_name(project_name, max_width)
  if #project_name <= max_width then
    local project_name_parsed, _ = string.gsub(project_name, '[%-_.]', ' ')
    return { project_name_parsed }
  end

  local parts = M._separate_project_name(project_name)
  local ret = {}
  local last_entry = false

  for i = 1, #parts do
    if i == 3 then
      last_entry = true
    end

    local part = parts[i]
    if not last_entry and #part <= max_width then
      table.insert(ret, part)
    else
      local concat_leftout_portion = table.concat(parts, ' ', i)
      for _, str in
        ipairs(M._split_string_given_max_width(concat_leftout_portion, max_width, 4 - i))
      do
        table.insert(ret, str)
      end
      break
    end
  end

  return ret
end

---Split a string into `n_splits` parts, with each part being at most `max_width` chars long
---@param project_name string
---@param max_width integer
---@param n_splits integer
---@return table<string>
function M._split_string_given_max_width(project_name, max_width, n_splits)
  local ret = {}

  for i = 1, n_splits do
    if #project_name > max_width then
      if i == n_splits then
        table.insert(ret, project_name:sub(1, max_width - 1) .. '…')
      else
        table.insert(ret, project_name:sub(1, max_width))
      end
      project_name = project_name:sub(max_width + 1)
    else
      table.insert(ret, project_name)
      break
    end
  end

  return ret
end

---Split the project name by `_`, `-`, and `.`
---@param project_name string
---@return table<string>
function M._separate_project_name(project_name)
  local result = {}
  for part in string.gmatch(project_name, '([^' .. '-_.' .. ']+)') do
    table.insert(result, part)
  end
  return result
end

---TODO: remove checks
---String substring compatible with multibyte characters.
---Start index: i. End index: j.
-- https://neovim.discourse.group/t/how-do-you-work-with-strings-with-multibyte-characters-in-lua/2437
---@param str string
---@param i integer
---@param j integer
---@return string
function M.str_sub(str, i, j)
  local length = vim.str_utfindex(str)
  if i < 0 then
    i = i + length + 1
  end
  if j and j < 0 then
    j = j + length + 1
  end
  local u = (i > 0) and i or 1
  local v = (j and j <= length) and j or length
  if u > v then
    return ''
  end
  local s = vim.str_byteindex(str, u - 1)
  local e = vim.str_byteindex(str, v)
  return str:sub(s + 1, e)
end

---Extract project name from its id
---@param project_id string
---@return string
function M.get_project_name(project_id)
  return project_id:match('([^/]+)/*$') or project_id
end

---Helper function that formats a duration in seconds and places it into a
---character array. Meant to be used for placing labels above bars.
---@param target_line_arr string[]
---@param label string
---@param bar_start_col integer
---@param bar_width integer
---@param highlights chronicles.Highlight[]
---@param highlights_line integer
---@param highlight? string
function M.place_label(
  target_line_arr,
  label,
  bar_start_col,
  bar_width,
  highlights,
  highlights_line,
  highlight
)
  local len_label = #label
  if len_label > bar_width then
    return
  end
  local label_start = bar_start_col + math.floor((bar_width - len_label) / 2)

  for i = 1, len_label do
    target_line_arr[label_start + i] = label:sub(i, i)
  end

  if highlight then
    table.insert(highlights, {
      line = highlights_line,
      col = label_start,
      end_col = label_start + len_label,
      hl_group = highlight,
    })
  end
end

return M
