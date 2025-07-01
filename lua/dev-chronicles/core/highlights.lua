local M = {}

M.setup_highlights = function()
  local highlights = {
    DevChroniclesRed = { fg = '#ff6b6b', bold = true },
    DevChroniclesBlue = { fg = '#4ecdc4', bold = true },
    DevChroniclesGreen = { fg = '#95e1d3', bold = true },
    DevChroniclesYellow = { fg = '#f9ca24', bold = true },
    DevChroniclesMagenta = { fg = '#f0932b', bold = true },
    DevChroniclesCyan = { fg = '#6c5ce7', bold = true },
    DevChroniclesOrange = { fg = '#ff7675', bold = true },
    DevChroniclesPurple = { fg = '#a29bfe', bold = true },
    DevChroniclesTitle = { fg = '#ffffff', bold = true },
    DevChroniclesLabel = { fg = '#b2bec3', bold = false },
    DevChroniclesTime = { fg = '#dddddd', bold = true },
  }

  for name, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

return M
