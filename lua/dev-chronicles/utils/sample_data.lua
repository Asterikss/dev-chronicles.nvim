local M = {}

---@return chronicles.ChroniclesData, integer mock_now
function M.get_sample_chronicles_data()
  local time_days = require('dev-chronicles.core.time.days')
  local mock_now = 1761876000 -- 31.10.2025 02:00:00 UTC

  local sample_data = {
    global_time = 572100,
    tracking_start = time_days.convert_day_str_to_timestamp('03.09.2025'),
    last_data_write = mock_now,
    schema_version = 1,
    projects = {
      llvm = {
        total_time = 112500,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 21500,
              ['10.2025'] = 91000,
            },
            total_time = 112500,
          },
        },
        by_day = {
          ['30.10.2025'] = 5400,
          ['29.10.2025'] = 7200,
          ['24.10.2025'] = 8100,
          ['22.10.2025'] = 5900,
          ['19.10.2025'] = 7800,
          ['16.10.2025'] = 6200,
          ['11.10.2025'] = 7400,
          ['06.10.2025'] = 5500,
          ['02.10.2025'] = 4200,
          ['25.09.2025'] = 5800,
          ['18.09.2025'] = 3900,
          ['12.09.2025'] = 4500,
          ['05.09.2025'] = 5200,
        },
        first_worked = time_days.convert_day_str_to_timestamp('05.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('31.10.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('30.10.2025', true),
        last_cleaned = time_days.convert_day_str_to_timestamp('05.10.2025'),
        color = 'E9842C',
      },
      tiktoken = {
        total_time = 67200,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 9500,
              ['10.2025'] = 57700,
            },
            total_time = 67200,
          },
        },
        by_day = {
          ['29.10.2025'] = 3600,
          ['27.10.2025'] = 4200,
          ['23.10.2025'] = 6100,
          ['20.10.2025'] = 4500,
          ['17.10.2025'] = 3800,
          ['14.10.2025'] = 4800,
          ['12.10.2025'] = 3300,
          ['08.10.2025'] = 5400,
          ['05.10.2025'] = 4100,
          ['03.10.2025'] = 3700,
          ['01.10.2025'] = 3200,
          ['28.09.2025'] = 4400,
          ['20.09.2025'] = 3500,
          ['10.09.2025'] = 4900,
          ['04.09.2025'] = 3100,
        },
        first_worked = time_days.convert_day_str_to_timestamp('04.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('29.10.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('29.10.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('28.10.2025'),
        color = '67AB6F',
      },
      ffmpeg = {
        total_time = 108900,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 16700,
              ['10.2025'] = 92200,
            },
            total_time = 108900,
          },
        },
        by_day = {
          ['30.10.2025'] = 7200,
          ['27.10.2025'] = 6800,
          ['24.10.2025'] = 9000,
          ['21.10.2025'] = 7500,
          ['18.10.2025'] = 8200,
          ['15.10.2025'] = 6900,
          ['10.10.2025'] = 7800,
          ['07.10.2025'] = 8400,
          ['03.10.2025'] = 7100,
          ['01.10.2025'] = 6500,
          ['26.09.2025'] = 5400,
          ['19.09.2025'] = 6200,
          ['14.09.2025'] = 5800,
          ['08.09.2025'] = 6400,
          ['03.09.2025'] = 5100,
        },
        first_worked = time_days.convert_day_str_to_timestamp('03.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('30.10.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('30.10.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('29.10.2025'),
        color = 'C74F6D',
      },
      mpv = {
        total_time = 64700,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 11900,
              ['10.2025'] = 52800,
            },
            total_time = 64700,
          },
        },
        by_day = {
          ['28.10.2025'] = 4500,
          ['21.10.2025'] = 1000,
          ['18.10.2025'] = 5900,
          ['16.10.2025'] = 6300,
          ['14.10.2025'] = 4700,
          ['11.10.2025'] = 5100,
          ['07.10.2025'] = 4900,
          ['04.10.2025'] = 5400,
          ['02.10.2025'] = 3800,
          ['30.09.2025'] = 4200,
          ['23.09.2025'] = 3600,
          ['16.09.2025'] = 4100,
          ['09.09.2025'] = 3900,
        },
        first_worked = time_days.convert_day_str_to_timestamp('09.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('28.10.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('28.10.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('27.10.2025'),
        color = '2e77c1',
      },
      tinygrad = {
        total_time = 47500,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 9900,
              ['10.2025'] = 37600,
            },
            total_time = 47500,
          },
        },
        by_day = {
          ['30.10.2025'] = 3300,
          ['26.10.2025'] = 3700,
          ['22.10.2025'] = 4100,
          ['19.10.2025'] = 3500,
          ['15.10.2025'] = 3900,
          ['11.10.2025'] = 4300,
          ['08.10.2025'] = 3200,
          ['04.10.2025'] = 3800,
          ['01.10.2025'] = 3600,
          ['27.09.2025'] = 2900,
          ['20.09.2025'] = 3400,
          ['13.09.2025'] = 3100,
          ['06.09.2025'] = 3300,
        },
        first_worked = time_days.convert_day_str_to_timestamp('06.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('30.10.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('30.10.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('29.10.2025'),
        color = '9973f8',
      },
      jujitsu = {
        total_time = 33100,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 8000,
              ['10.2025'] = 25100,
            },
            total_time = 33100,
          },
        },
        by_day = {
          ['27.10.2025'] = 2700,
          ['23.10.2025'] = 3200,
          ['17.10.2025'] = 2900,
          ['12.10.2025'] = 3400,
          ['05.10.2025'] = 3100,
          ['02.10.2025'] = 3300,
          ['29.09.2025'] = 2500,
          ['22.09.2025'] = 2900,
          ['14.09.2025'] = 2600,
          ['07.09.2025'] = 2800,
        },
        first_worked = time_days.convert_day_str_to_timestamp('07.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('27.10.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('27.10.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('26.10.2025'),
        color = 'b09e5e',
      },
      xla = {
        total_time = 49500,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 49500,
            },
            total_time = 49500,
          },
        },
        by_day = {
          ['30.09.2025'] = 5400,
          ['27.09.2025'] = 4800,
          ['23.09.2025'] = 5200,
          ['19.09.2025'] = 4600,
          ['15.09.2025'] = 5100,
          ['11.09.2025'] = 4900,
          ['07.09.2025'] = 5300,
          ['04.09.2025'] = 4700,
        },
        first_worked = time_days.convert_day_str_to_timestamp('04.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('30.09.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('30.09.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('26.10.2025'),
        color = 'a29bfe',
      },
      fzf = {
        total_time = 27500,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 27500,
            },
            total_time = 27500,
          },
        },
        by_day = {
          ['28.09.2025'] = 3600,
          ['24.09.2025'] = 3900,
          ['20.09.2025'] = 3700,
          ['16.09.2025'] = 4100,
          ['12.09.2025'] = 3800,
          ['08.09.2025'] = 4000,
          ['05.09.2025'] = 3500,
        },
        first_worked = time_days.convert_day_str_to_timestamp('05.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('28.09.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('28.09.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('26.10.2025'),
      },
      yazi = {
        total_time = 42700,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 42700,
            },
            total_time = 42700,
          },
        },
        by_day = {
          ['25.09.2025'] = 4200,
          ['21.09.2025'] = 4500,
          ['17.09.2025'] = 4300,
          ['13.09.2025'] = 4700,
          ['09.09.2025'] = 4400,
          ['06.09.2025'] = 4600,
        },
        first_worked = time_days.convert_day_str_to_timestamp('06.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('25.09.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('25.09.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('26.09.2025'),
        color = '00d9ff',
      },
      ripgrep = {
        total_time = 18500,
        by_year = {
          ['2025'] = {
            by_month = {
              ['09.2025'] = 18500,
            },
            total_time = 18500,
          },
        },
        by_day = {
          ['26.09.2025'] = 2800,
          ['22.09.2025'] = 3100,
          ['18.09.2025'] = 2900,
          ['14.09.2025'] = 3200,
          ['10.09.2025'] = 3000,
          ['05.09.2025'] = 3300,
        },
        first_worked = time_days.convert_day_str_to_timestamp('05.09.2025'),
        last_worked = time_days.convert_day_str_to_timestamp('26.09.2025'),
        last_worked_canonical = time_days.convert_day_str_to_timestamp('26.09.2025'),
        last_cleaned = time_days.convert_day_str_to_timestamp('26.09.2025'),
        color = '9d5900',
      },
    },
  }

  return sample_data, mock_now
end

return M
