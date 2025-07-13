local M = {}

---Unrolls provided bar representation pattern to match `bar_width`. If it
---fails, returns the fallback bar representation consisting of `@`. Also return
---codepoints counts for all the rows and char display width foe each character in
---each row
---@param pattern string[]
---@param bar_width integer
---@return string[], integer[], integer[][]
M.construct_bar_string_tbl_representation = function(pattern, bar_width)
  local str_sub = require('dev-chronicles.utils.strings').str_sub
  local realized_bar_repr = {}
  local bar_rows_codepoints = {}
  local bar_rows_chars_disp_width = {}

  for _, row_chars in ipairs(pattern) do
    local tmp_bar_rows_char_disp_widths = {}
    local row_chars_display_width = 0
    local row_chars_codepoint = vim.str_utfindex(row_chars)

    for i = 1, row_chars_codepoint do
      local char = str_sub(row_chars, i, i)
      local char_display_width = vim.fn.strdisplaywidth(char)
      row_chars_display_width = row_chars_display_width + char_display_width
      table.insert(tmp_bar_rows_char_disp_widths, char_display_width)
    end

    local n_to_fill_bar_width = bar_width / row_chars_display_width
    local bar_rows_char_disp_widths_entry = {}

    if n_to_fill_bar_width ~= math.floor(n_to_fill_bar_width) then
      vim.notify(
        'provided bar_chars row characters: '
          .. row_chars
          .. ' cannot be smoothly expanded to bar_width='
          .. tostring(bar_width)
          .. ' given their display_width='
          .. tostring(row_chars_display_width)
          .. '. Falling back to @ bar representation'
      )
      for i = 1, bar_width do
        bar_rows_char_disp_widths_entry[i] = 1
      end
      return { string.rep('@', bar_width) }, { bar_width }, { bar_rows_char_disp_widths_entry }
    end

    local len_tmp_bar_rows_char_disp_widths = #tmp_bar_rows_char_disp_widths

    for i = 1, #tmp_bar_rows_char_disp_widths * n_to_fill_bar_width do
      bar_rows_char_disp_widths_entry[i] =
        tmp_bar_rows_char_disp_widths[((i - 1) % len_tmp_bar_rows_char_disp_widths) + 1]
    end

    local row = string.rep(row_chars, n_to_fill_bar_width)

    table.insert(realized_bar_repr, row)
    table.insert(bar_rows_codepoints, n_to_fill_bar_width * row_chars_codepoint)
    table.insert(bar_rows_chars_disp_width, bar_rows_char_disp_widths_entry)
  end

  -- `bar_rows_codepoints` entries can be deduced by the length of
  -- `bar_rows_chars_disp_width` entries, but that's O(n) and I already
  -- calculate `n_to_fill_bar_width` and `row_chars_codepoint` anyway, so I
  -- will construct a helper array here. The reason why
  -- `bar_rows_chars_disp_width` is needed is for characters that take more
  -- than one column to work. It contains tables for each row, since you can
  -- supply multiple characters to construct a row of the bar, where each
  -- character can have a different display width and a different number of
  -- bytes.
  return realized_bar_repr, bar_rows_codepoints, bar_rows_chars_disp_width
end

return M
