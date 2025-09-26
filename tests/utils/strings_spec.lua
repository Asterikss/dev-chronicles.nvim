local strings = require('dev-chronicles.utils.strings')

describe('utils.strings', function()
  describe('format_project_name', function()
    local max_width = 11

    it('returns single cleaned part if whole name fits', function()
      assert.are.same({ 'abc abcabc' }, strings.format_project_name('abc-abcabc', max_width))
    end)

    it('splits two-part name that are longer than max_width', function()
      assert.are.same({ 'name', 'project' }, strings.format_project_name('name-project', max_width))
    end)

    it('splits too-long single part into multiple', function()
      assert.are.same(
        { 'abcheyyyloo', 'ong' },
        strings.format_project_name('abcheyyylooong', max_width)
      )
    end)

    it(
      'splits into 3 parts if the whole name is longer than max_width, even thought any two parts could fit on one line',
      function()
        assert.are.same(
          { 'abc', 'there', 'is' },
          strings.format_project_name('abc-there-is', max_width)
        )
      end
    )

    it('merges leftover parts when there would be four', function()
      assert.are.same(
        { 'abc', 'where', 'is it' },
        strings.format_project_name('abc-where-is-it', max_width)
      )
    end)

    it('merges leftover parts when there would be four and trucates if needed', function()
      assert.are.same(
        { 'abc', 'where', 'is it trun…' },
        strings.format_project_name('abc-where-is-it-truncates', max_width)
      )
    end)

    it('keeps long first part and splits remaining correctly', function()
      assert.are.same(
        { '12character', 's aaaa bb' },
        strings.format_project_name('12characters-aaaa-bb', max_width)
      )
    end)

    it('handles parts longer than max_width in the middle of the split', function()
      assert.are.same(
        { 'aaaa', '12character', 's BB' },
        strings.format_project_name('aaaa-12characters-BB', max_width)
      )
    end)

    it('handles long names where multiple max-length violation are present', function()
      assert.are.same(
        { '~/projects/', 'project nam', 'efoo bar/' },
        strings.format_project_name('~/projects/project-namefoo.bar/', max_width)
      )
    end)
  end)

  describe('_separate_project_name', function()
    it('handles leading and trailing separators', function()
      local result = strings._separate_project_name('_hello-world_')
      assert.are.same({ 'hello', 'world' }, result)
    end)

    it('handles consecutive separators gracefully', function()
      local result = strings._separate_project_name('hello__world--foo..bar')
      assert.are.same({ 'hello', 'world', 'foo', 'bar' }, result)
    end)

    it('returns full string if no separators', function()
      local result = strings._separate_project_name('helloworld')
      assert.are.same({ 'helloworld' }, result)
    end)
  end)

  describe('get_project_name', function()
    it('extracts project name from simple id without any slashes', function()
      assert.are.equal('project', strings.get_project_name('project'))
    end)

    it('extracts project name from nested path', function()
      assert.are.equal('project', strings.get_project_name('org/team/project'))
    end)

    it('extracts project name from path ending with slash', function()
      assert.are.equal('project', strings.get_project_name('org/team/project/'))
    end)

    it('returns original value if no match found', function()
      assert.are.equal('', strings.get_project_name(''))
    end)

    it('handles weird trailing slashes correctly', function()
      assert.are.equal('project', strings.get_project_name('//aa//project///'))
    end)
  end)
end)
