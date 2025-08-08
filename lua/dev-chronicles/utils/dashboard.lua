local M = {}

---Unrolls provided bar representation pattern to match the width of each BarLevel. Upon
---failure, returns the fallback bar representation consisting of `@`. Also returns
---codepoints counts for all the rows and char display width for each character in
---each row.
---@param pattern string[][]
---@param bar_width integer
---@param bar_header_extends_by integer
---@param bar_footer_extends_by integer
---@return chronicles.BarRepresentation
M.construct_bar_representation = function(
  pattern,
  bar_width,
  bar_header_extends_by,
  bar_footer_extends_by
)
  local str_sub = require('dev-chronicles.utils.strings').str_sub
  local bar_representation = {}
  local return_bar_header_extends_by = bar_header_extends_by
  local return_bar_footer_extends_by = bar_footer_extends_by
  local keys = { 'header', 'body', 'footer' }

  for j = 1, 3 do
    local realized_rows = {}
    local row_codepoint_counts = {}
    local char_display_widths = {}
    local width = bar_width

    if j == 1 then
      width = bar_width + (return_bar_header_extends_by * 2)
    elseif j == 3 then
      width = bar_width + (return_bar_footer_extends_by * 2)
    elseif j == 2 and next(pattern[j]) == nil then
      vim.notify(
        'DevChronicles Error: bar_chars BodyLevel (middle one) cannot be empty. Falling back to @ bar representation'
      )
      return M._construct_fallback_bar_representation(bar_width)
    end

    for _, row_chars in ipairs(pattern[j]) do
      local tmp_char_display_widths = {}
      local row_chars_display_width = 0
      local row_chars_codepoints = vim.str_utfindex(row_chars)

      for i = 1, row_chars_codepoints do
        local char = str_sub(row_chars, i, i)
        local char_display_width = vim.fn.strdisplaywidth(char)
        row_chars_display_width = row_chars_display_width + char_display_width
        table.insert(tmp_char_display_widths, char_display_width)
      end

      local n_to_fill_bar_width

      if row_chars_display_width == width then
        table.insert(char_display_widths, tmp_char_display_widths)
        n_to_fill_bar_width = 1
      else
        n_to_fill_bar_width = width / row_chars_display_width

        if n_to_fill_bar_width ~= math.floor(n_to_fill_bar_width) then
          vim.notify(
            'DevChronicles: provided bar_chars row characters in '
              .. keys[j]
              .. ' level: '
              .. row_chars
              .. ' cannot be smoothly expanded to width='
              .. tostring(width)
              .. ' given their display_width='
              .. tostring(row_chars_display_width)
              .. '. Falling back to @ bar representation'
          )
          return M._construct_fallback_bar_representation(bar_width)
        end

        local char_display_widths_entry = {}
        local len_tmp_char_display_widths = #tmp_char_display_widths

        for i = 1, #tmp_char_display_widths * n_to_fill_bar_width do
          char_display_widths_entry[i] =
            tmp_char_display_widths[((i - 1) % len_tmp_char_display_widths) + 1]
        end

        table.insert(char_display_widths, char_display_widths_entry)
      end

      local row = string.rep(row_chars, n_to_fill_bar_width)
      table.insert(realized_rows, row)
      table.insert(row_codepoint_counts, n_to_fill_bar_width * row_chars_codepoints)
    end

    bar_representation[keys[j]] = {
      realized_rows = realized_rows,
      row_codepoint_counts = row_codepoint_counts,
      char_display_widths = char_display_widths,
    }
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
  return bar_representation
end

---@param bar_width integer
---@return chronicles.BarRepresentation
M._construct_fallback_bar_representation = function(bar_width)
  local bar_representation = {}
  local char_display_widths_entry = {}
  for i = 1, bar_width do
    char_display_widths_entry[i] = 1
  end
  bar_representation.header = {
    realized_rows = {},
    row_codepoint_counts = {},
    char_display_widths = {},
  }
  bar_representation.body = {
    realized_rows = { string.rep('@', bar_width) },
    row_codepoint_counts = { bar_width },
    char_display_widths = { char_display_widths_entry },
  }
  bar_representation.footer = {
    realized_rows = {},
    row_codepoint_counts = {},
    char_display_widths = {},
  }
  return bar_representation
end

return M
