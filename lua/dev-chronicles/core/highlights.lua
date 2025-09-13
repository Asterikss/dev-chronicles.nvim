local M = {}

function M.setup_highlights()
  local colors = {
    DevChroniclesRed = { fg = '#ff6b6b', bold = true },
    DevChroniclesBlue = { fg = '#5F91FD', bold = true },
    DevChroniclesGreen = { fg = '#95e1d3', bold = true },
    DevChroniclesYellow = { fg = '#f9ca24', bold = true },
    DevChroniclesMagenta = { fg = '#8b008b', bold = true },
    DevChroniclesPurple = { fg = '#6c5ce7', bold = true },
    DevChroniclesOrange = { fg = '#ffa500', bold = true },
    DevChroniclesLightPurple = { fg = '#a29bfe', bold = true },
  }

  for name, opts in pairs(colors) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

return M
