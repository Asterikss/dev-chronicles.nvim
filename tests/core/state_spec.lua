local state = require('dev-chronicles.core.state')
local stub = require('luassert.stub')

describe('core.state integration', function()
  local core = require('dev-chronicles.core')
  local time_days = require('dev-chronicles.core.time.days')
  local orig_get_canonical_curr_ts_and_day_str = time_days.get_canonical_curr_ts_and_day_str

  local NOW_TS = 1760787574 -- 18.10.2025 13:39:34
  local CANONICAL_TS = 1760787574
  local CANONICAL_DAY = '18.10.2025'
  local CANONICAL_MONTH = '10.2025'
  local CANONICAL_YEAR = '2025'
  local extend_today_to_4am = true

  local opts = {
    tracked_parent_dirs = {},
    tracked_dirs = {},
    exclude_dirs_absolute = {},
    differentiate_projects_by_folder_not_path = true,
    runtime_opts = {
      parsed_exclude_subdirs_relative_map = {},
      for_dev_state_override = nil,
    },
  }

  local is_project_stub
  local os_time_stub
  local get_canonical_curr_ts_and_day_str_stub

  before_each(function()
    state.abort_session()

    is_project_stub = stub(core, 'is_project', function()
      return 'dev-chronicles.nvim', 'dev-chronicles.nvim'
    end)

    os_time_stub = stub(os, 'time', function()
      return NOW_TS
    end)

    get_canonical_curr_ts_and_day_str_stub = stub(
      time_days,
      'get_canonical_curr_ts_and_day_str',
      function(extend_today_to_4am_arg, _timestamp)
        return orig_get_canonical_curr_ts_and_day_str(extend_today_to_4am_arg, NOW_TS)
      end
    )
  end)

  after_each(function()
    if is_project_stub then
      is_project_stub:revert()
    end
    if os_time_stub then
      os_time_stub:revert()
    end
    if get_canonical_curr_ts_and_day_str_stub then
      get_canonical_curr_ts_and_day_str_stub:revert()
    end
  end)

  it('handles full session lifecycle correctly', function()
    -- 1. No session yet
    local base, active = state.get_session_info(extend_today_to_4am)
    assert.are.same({
      canonical_ts = CANONICAL_TS,
      canonical_today_str = CANONICAL_DAY,
      canonical_month_str = CANONICAL_MONTH,
      canonical_year_str = CANONICAL_YEAR,
      now_ts = NOW_TS,
      changes = nil,
    }, base)
    assert.is_nil(active)

    -- 2. Start a session
    state.start_session(opts)

    -- 3. Check session info after starting
    base, active = state.get_session_info(extend_today_to_4am)
    assert.are.same({
      canonical_ts = CANONICAL_TS,
      canonical_today_str = CANONICAL_DAY,
      canonical_month_str = CANONICAL_MONTH,
      canonical_year_str = CANONICAL_YEAR,
      now_ts = NOW_TS,
      changes = nil,
    }, base)

    assert.are.same({
      project_id = 'dev-chronicles.nvim',
      project_name = 'dev-chronicles.nvim',
      start_time = NOW_TS,
      session_time = NOW_TS - NOW_TS,
    }, active)

    -- 4. Set changes and verify if reflected
    local new_changes = {
      new_colors = { project_bar = '#FFFFFF' },
      to_be_deleted = { project_foo = true },
    }
    state.set_changes(new_changes)

    base, active = state.get_session_info(extend_today_to_4am)
    assert.are.same(new_changes, base.changes)
    if not active then
      error('Expected session_active to not be nil')
    end
    assert.are.same('dev-chronicles.nvim', active.project_name)

    -- 5. Abort and verify reset
    state.abort_session()

    base, active = state.get_session_info(extend_today_to_4am)
    assert.are.same({
      canonical_ts = CANONICAL_TS,
      canonical_today_str = CANONICAL_DAY,
      canonical_month_str = CANONICAL_MONTH,
      canonical_year_str = CANONICAL_YEAR,
      now_ts = NOW_TS,
      changes = nil,
    }, base)
    assert.is_nil(active)
  end)

  it('handles for_dev_state_override correctly (non 0 session time too)', function()
    local START_TS = 1760783872 -- 18.10.2025 12:37:52
    local new_opts = vim.deepcopy(opts)
    new_opts.runtime_opts.for_dev_state_override = {
      project_id = 'test-dev-chronicles.nvim',
      project_name = 'test-dev-chronicles.nvim',
      start_time = START_TS,
      elapsed_so_far = nil,
      changes = nil,
      is_tracking = true,
    }

    state.start_session(new_opts)

    local _base, active = state.get_session_info(extend_today_to_4am)

    assert.are.same({
      project_id = 'test-dev-chronicles.nvim',
      project_name = 'test-dev-chronicles.nvim',
      start_time = START_TS,
      session_time = NOW_TS - START_TS,
    }, active)
  end)
end)
