local M = {}

local state = require('dev-chronicles.core.state')
local notify = require('dev-chronicles.utils.notify')

---@param extend_today_to_4am? boolean
function M.pause(extend_today_to_4am)
  extend_today_to_4am = extend_today_to_4am
    or require('dev-chronicles.config').get_opts().extend_today_to_4am

  local _, session_active = state.get_session_info(extend_today_to_4am)
  if not session_active then
    notify.notify('Not in a tracked session')
    return
  end

  if session_active.paused then
    M._unpause_session_helper()
    return
  end

  local did_succeed = state.pause_session()
  if did_succeed then
    notify.notify('Paused the session')
  else
    notify.notify('Pausing the session failed')
    return
  end

  local lines, n_lines = { '', ' Paused ', ' ' }, 3
  local max_width = #lines[2]

  local actions = {
    ['q'] = function(context)
      M._unpause_session_helper()
      vim.api.nvim_win_close(context.win, true)
    end,
    ['<CR>'] = function(context)
      M._unpause_session_helper()
      vim.api.nvim_win_close(context.win, true)
    end,
  }

  require('dev-chronicles.core.render').render({
    buf_name = 'DevChronicles paused',
    lines = lines,
    actions = actions,
    window_dimensions = require('dev-chronicles.utils').get_window_dimensions_fixed(
      max_width,
      n_lines
    ),
  })
end

function M._unpause_session_helper()
  local did_succeed = state.unpause_session()
  if did_succeed then
    notify.notify('Unpaused the session')
  else
    notify.notify('Unpausing the session failed')
  end
end

return M
