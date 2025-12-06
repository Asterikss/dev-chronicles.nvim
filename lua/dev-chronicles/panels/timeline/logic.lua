local M = {}

---@param row_repr string
---@param bar_width integer
---@return chronicles.Timeline.RowRepresentation
function M.construct_row_representation(row_repr, bar_width)
  local notify = require('dev-chronicles.utils.notify')
  local str_sub = require('dev-chronicles.utils.strings').str_sub

  ---@type integer, integer
  local row_repr_codepoints, row_repr_display_width = vim.str_utfindex(row_repr), 0
  ---@type integer[], integer[]
  local row_char_display_widths, tmp_row_char_display_widths = {}, {}
  ---@type integer[], integer[]
  local row_char_bytes, tmp_row_char_bytes = {}, {}
  ---@type string[], string[]
  local row_chars, tmp_row_chars = {}, {}
  local row_bytes, tmp_row_bytes = 0, 0

  for i = 1, row_repr_codepoints do
    local char = str_sub(row_repr, i, i)
    tmp_row_chars[i] = char

    local char_display_width = vim.fn.strdisplaywidth(char)
    row_repr_display_width = row_repr_display_width + char_display_width
    tmp_row_char_display_widths[i] = char_display_width

    local char_bytes = #char
    tmp_row_char_bytes[i] = char_bytes
    tmp_row_bytes = tmp_row_bytes + char_bytes
  end

  local n_to_fill_bar_width

  if row_repr_display_width == bar_width then
    row_char_display_widths = tmp_row_char_display_widths
    row_char_bytes = tmp_row_char_bytes
    row_chars = tmp_row_chars
    row_bytes = tmp_row_bytes
    n_to_fill_bar_width = 1
  else
    n_to_fill_bar_width = bar_width / row_repr_display_width

    if n_to_fill_bar_width ~= math.floor(n_to_fill_bar_width) then
      notify.warn(
        'Provided row_repr row characters: '
          .. row_repr
          .. ' cannot be smoothly expanded to width='
          .. tostring(bar_width)
          .. ' given their display_width='
          .. tostring(row_repr_display_width)
          .. '. Falling back to @ bar representation'
      )
      local fallback_char = '@'
      for i = 1, bar_width do
        row_char_display_widths[i] = 1
        row_chars[i] = fallback_char
      end
      ---@type chronicles.Timeline.RowRepresentation
      return {
        realized_row = fallback_char:rep(bar_width),
        row_codepoint_count = bar_width,
        row_display_width = bar_width,
        row_bytes = bar_width,
        row_chars = row_chars,
        row_char_display_widths = row_char_display_widths,
        row_char_bytes = row_char_display_widths,
      }
    end

    -- The length of tmp_row_char_display_widths should always equal row_repr_codepoints.
    -- Also the length of both row_char_display_widths and row_char_bytes should equal
    -- row_codepoint_count.
    for i = 1, row_repr_codepoints * n_to_fill_bar_width do
      local next_index = ((i - 1) % row_repr_codepoints) + 1
      row_char_display_widths[i] = tmp_row_char_display_widths[((i - 1) % row_repr_codepoints) + 1]

      row_chars[i] = tmp_row_chars[next_index]

      local next_byte_count = tmp_row_char_bytes[((i - 1) % row_repr_codepoints) + 1]
      row_char_bytes[i] = next_byte_count
      row_bytes = row_bytes + next_byte_count
    end
  end

  local realized_row = string.rep(row_repr, n_to_fill_bar_width)
  local row_codepoint_count = row_repr_codepoints * n_to_fill_bar_width

  assert(
    bar_width == row_repr_codepoints * row_repr_display_width * n_to_fill_bar_width,
    'Timeline: construct_row_representation: row_width should equal row_repr_codepoints * row_repr_display_width * n_to_fill_bar_width'
  )

  ---@type chronicles.Timeline.RowRepresentation
  return {
    realized_row = realized_row,
    row_codepoint_count = row_codepoint_count,
    row_display_width = bar_width,
    row_bytes = row_bytes,
    row_chars = row_chars,
    row_char_display_widths = row_char_display_widths,
    row_char_bytes = row_char_bytes,
  }
end

---@param timeline_data chronicles.Timeline.Data
---@param n_segments integer
---@param n_segments_to_keep integer
function M.cut_off_segments(timeline_data, n_segments, n_segments_to_keep)
  ---@type chronicles.Timeline.SegmentData[]
  local kept_segments, len_kept_segments = {}, 0
  local cutoff_start = n_segments - n_segments_to_keep + 1

  for i = cutoff_start, n_segments do
    len_kept_segments = len_kept_segments + 1
    kept_segments[len_kept_segments] = timeline_data.segments[i]
  end

  -- A segment whose `total_segment_time` equals `max_segment_time` could have been cut off
  local max_segment_time = timeline_data.max_segment_time
  for i = 1, cutoff_start - 1 do
    if timeline_data.segments[i].total_segment_time == max_segment_time then
      local new_max_segment_time = 0

      for _, segment_data in ipairs(kept_segments) do
        new_max_segment_time = math.max(segment_data.total_segment_time, new_max_segment_time)
      end

      timeline_data.max_segment_time = new_max_segment_time
      break
    end
  end

  timeline_data.segments = kept_segments
end

return M
