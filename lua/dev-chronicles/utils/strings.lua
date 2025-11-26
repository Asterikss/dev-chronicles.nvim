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

---Splits `project_name` by `_`, `-`, and `.`
---@param project_name string
---@return string[]
function M._separate_project_name(project_name)
  local result, len_result = {}, 0
  for part in project_name:gmatch('[^%._-]+') do
    len_result = len_result + 1
    result[len_result] = part
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

---Extracts project name from its id.
---@param project_id string
---@return string
function M.get_project_name(project_id)
  return project_id:match('([^/]+)/*$') or project_id
end

---Places a label into a character array. This "simple" variant assumes all
---characters in `label` are single-byte and occupy one cell. Designed as a
---helper for positioning textual labels relative to rendered bars.
---@param target_line_arr string[]
---@param label string
---@param left_margin_col integer
---@param available_width integer
---@param highlights chronicles.Highlight[]
---@param highlights_line integer
---@param highlight? string
function M.place_label_simple(
  target_line_arr,
  label,
  left_margin_col,
  available_width,
  highlights,
  highlights_line,
  highlight
)
  local len_label = #label
  if len_label > available_width then
    return
  end
  local label_left_margin_col = left_margin_col + math.floor((available_width - len_label) / 2)

  for i = 1, len_label do
    target_line_arr[label_left_margin_col + i] = label:sub(i, i)
  end

  if highlight then
    table.insert(highlights, {
      line = highlights_line,
      col = label_left_margin_col,
      end_col = label_left_margin_col + len_label,
      hl_group = highlight,
    })
  end
end

---Places a label into a character array. Designed as a helper for positioning
---textual labels relative to rendered bars. Returns `hl_bytes_shift`, if any.
---@param target_line_arr string[]
---@param label string
---@param left_margin_col integer
---@param available_width integer
---@param highlights chronicles.Highlight[]
---@param highlights_line integer
---@param highlight? string
---@param hl_bytes_shift? integer
---@return integer: hl_bytes_shift
function M.place_label(
  target_line_arr,
  label,
  left_margin_col,
  available_width,
  highlights,
  highlights_line,
  highlight,
  hl_bytes_shift
)
  local label_display_width = vim.fn.strdisplaywidth(label)
  if label_display_width > available_width then
    return 0
  end

  local label_left_margin_col = left_margin_col
    + math.floor((available_width - label_display_width) / 2)
  local label_curr_col = label_left_margin_col

  for i = 1, vim.str_utfindex(label) do
    local char = M.str_sub(label, i, i)
    local char_disp_width = vim.fn.strdisplaywidth(char)

    label_curr_col = label_curr_col + 1
    target_line_arr[label_curr_col] = char

    for j = 1, char_disp_width - 1 do
      target_line_arr[label_curr_col + j] = ''
    end
    label_curr_col = label_curr_col + char_disp_width - 1
  end

  if highlight then
    hl_bytes_shift = hl_bytes_shift or 0
    local label_bytes = #label

    table.insert(highlights, {
      line = highlights_line,
      col = label_left_margin_col + hl_bytes_shift,
      end_col = label_left_margin_col + label_bytes + hl_bytes_shift,
      hl_group = highlight,
    })

    return label_bytes - label_display_width
  end

  return 0
end

return M
