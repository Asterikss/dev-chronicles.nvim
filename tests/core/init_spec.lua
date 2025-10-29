local core = require('dev-chronicles.core')

describe('core.is_project', function()
  local real_os_homedir

  before_each(function()
    real_os_homedir = vim.uv.os_homedir
    vim.uv.os_homedir = function()
      return '/home/user'
    end
  end)

  after_each(function()
    vim.uv.os_homedir = real_os_homedir
  end)

  local function new_test_fixture()
    return {
      cwd = '/home/user/projects/foo/',
      tracked_parent_dirs = {},
      tracked_dirs = {},
      exclude_dirs_absolute = {},
      parsed_exclude_subdirs_relative_map = {},
      differentiate_projects_by_folder_not_path = true,
    }
  end

  it('returns nil when cwd is inside an excluded absolute dir', function()
    local f = new_test_fixture()
    f.tracked_parent_dirs = { '/home/user/projects/' }
    f.exclude_dirs_absolute = { '/home/user/projects/foo/' }

    local project_id, project_name = core.is_project(
      f.cwd,
      f.tracked_parent_dirs,
      f.tracked_dirs,
      f.exclude_dirs_absolute,
      f.parsed_exclude_subdirs_relative_map,
      f.differentiate_projects_by_folder_not_path
    )

    assert.is_nil(project_id)
    assert.is_nil(project_name)
  end)

  it('returns correct id and project name for a directly tracked directory', function()
    local f = new_test_fixture()
    f.tracked_dirs = { '/home/user/projects/foo/' }

    local project_id, project_name = core.is_project(
      f.cwd,
      f.tracked_parent_dirs,
      f.tracked_dirs,
      f.exclude_dirs_absolute,
      f.parsed_exclude_subdirs_relative_map,
      f.differentiate_projects_by_folder_not_path
    )

    assert.are.equal(project_id, 'foo')
    assert.are.equal(project_name, 'foo')
  end)

  it(
    'returns expanded project id when differentiate_projects_by_folder_not_path = false for tracked_dirs',
    function()
      local f = new_test_fixture()
      f.tracked_dirs = { '/home/user/projects/foo/' }
      f.differentiate_projects_by_folder_not_path = false

      local project_id, project_name = core.is_project(
        f.cwd,
        f.tracked_parent_dirs,
        f.tracked_dirs,
        f.exclude_dirs_absolute,
        f.parsed_exclude_subdirs_relative_map,
        f.differentiate_projects_by_folder_not_path
      )

      assert.are.equal(project_id, '~/projects/foo/')
      assert.are.equal(project_name, 'foo')
    end
  )

  it(
    'returns expanded project id when differentiate_projects_by_folder_not_path = false for tracked_parent_dirs',
    function()
      local f = new_test_fixture()
      f.tracked_parent_dirs = { '/home/user/projects/' }
      f.differentiate_projects_by_folder_not_path = false

      local project_id, project_name = core.is_project(
        f.cwd,
        f.tracked_parent_dirs,
        f.tracked_dirs,
        f.exclude_dirs_absolute,
        f.parsed_exclude_subdirs_relative_map,
        f.differentiate_projects_by_folder_not_path
      )

      assert.are.equal(project_id, '~/projects/foo/')
      assert.are.equal(project_name, 'foo')
    end
  )

  it('returns nil for a tracked parent directory itself', function()
    local f = new_test_fixture()
    f.cwd = '/home/user/projects/'
    f.tracked_parent_dirs = { '/home/user/projects/' }

    local project_id, project_name = core.is_project(
      f.cwd,
      f.tracked_parent_dirs,
      f.tracked_dirs,
      f.exclude_dirs_absolute,
      f.parsed_exclude_subdirs_relative_map,
      f.differentiate_projects_by_folder_not_path
    )

    assert.is_nil(project_id)
    assert.is_nil(project_name)
  end)

  it('detects a subproject within a tracked parent directory', function()
    local f = new_test_fixture()
    f.tracked_parent_dirs = { '/home/user/projects/' }

    local project_id, project_name = core.is_project(
      f.cwd,
      f.tracked_parent_dirs,
      f.tracked_dirs,
      f.exclude_dirs_absolute,
      f.parsed_exclude_subdirs_relative_map,
      f.differentiate_projects_by_folder_not_path
    )

    assert.are.equal(project_id, 'foo')
    assert.are.equal(project_name, 'foo')
  end)

  it('skips excluded subprojects listed in the relative exclude map', function()
    local f = new_test_fixture()
    f.tracked_parent_dirs = { '/home/user/projects/' }
    f.parsed_exclude_subdirs_relative_map = { ['foo/'] = true }

    local project_id, project_name = core.is_project(
      f.cwd,
      f.tracked_parent_dirs,
      f.tracked_dirs,
      f.exclude_dirs_absolute,
      f.parsed_exclude_subdirs_relative_map,
      f.differentiate_projects_by_folder_not_path
    )

    assert.is_nil(project_id)
    assert.is_nil(project_name)
  end)

  it('appends missing trailing slash to cwd before evaluating', function()
    local f = new_test_fixture()
    f.tracked_dirs = { '/home/user/projects/foo/' }

    local project_id, project_name = core.is_project(
      f.cwd,
      f.tracked_parent_dirs,
      f.tracked_dirs,
      f.exclude_dirs_absolute,
      f.parsed_exclude_subdirs_relative_map,
      f.differentiate_projects_by_folder_not_path
    )

    assert.are.equal(project_id, 'foo')
    assert.are.equal(project_name, 'foo')
  end)
end)
