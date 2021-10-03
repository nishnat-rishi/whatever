local reminder = {
  states = {
    upcoming = 1,
    pending = 2,
    ongoing = 3,
    completed = 4
  }
}
reminder.__index = reminder
local id

function reminder:init(params)
  id = params.id
end

function reminder:create_dummy()
  local now = os.date('*t')
  local new = {
    id = 'fakeid1234',
    -- message = 'This is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder with lots of words to test whether the wrapping mechanism actually works or not.\n\nMoreover, this has double spacing as well. This is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder with lots of words to test whether the wrapping mechanism actually works or not.\n\nMoreover, this has double spacing as well.',
    message = 'This is a\ttabbed dummy reminder \\ with slashes \\\\ and "quotes", (\'single ones as well\') with lots of words.\n\nMoreover, this has double spacing as well.',
    created_on = os.time(now),
    last_modified_on = os.time(now),
    state = reminder.states.upcoming,
    time = {
      hour =  12,
      min = 24,
      sec = 47
    },
    constraints = {
      -- event = {
      --   completed = {},
      --   pending = {},
      --   ongoing = {},
      --   upcoming = {}
      -- },
      date = {
        addendum = {
          days = false,
          months = false,
          years = true,
          weekdays = false,
          -- days = true,
          -- months = true,
          -- years = true,
          -- weekdays = true,
          skip_ref = {
            day = 14,
            month = 9,
            year = 2021,
            sec = 0,
            min = 0,
            hour = 0
          },
        },
        lists = {
          days = {[24] = true, [23] = true, [22] = true, [21] = true, [20] = true, [19] = true},
          months = {[11] = true, [10] = true},
          years = {[2021] = true},
          weekdays = {[1] = true, [2] = true},
          skipdays = {[2] = true,[6] = false}
          -- days = {},
          -- months = {},
          -- years = {},
          -- weekdays = {},
          -- skipdays = {[2] = true, [3] = false},
        }
      }
    }
  }

  return new
end

function reminder:create_empty()
  local now = os.date('*t')
  local new = {
    -- id = 'fakeid1234',
    -- message = 'This is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder with lots of words to test whether the wrapping mechanism actually works or not.\n\nMoreover, this has double spacing as well. This is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder is a dummy reminder with lots of words to test whether the wrapping mechanism actually works or not.\n\nMoreover, this has double spacing as well.',
    -- created_on = os.time(now),
    -- last_modified_on = os.time(now),
    -- state = reminder.states.upcoming,
    -- time = {
    --   hour =  12,
    --   min = 24,
    --   sec = 47
    -- },
    constraints = {
      -- event = {
      --   completed = {},
      --   pending = {},
      --   ongoing = {},
      --   upcoming = {}
      -- },
      date = {
        addendum = {
          -- days = true,
          -- months = true,
          -- years = true,
          -- weekdays = true,
          -- skip_ref = {
          --   day = 14,
          --   month = 9,
          --   year = 2021,
          --   sec = 0,
          --   min = 0,
          --   hour = 0
          -- },
        },
        lists = {
          -- days = {},
          -- months = {},
          -- years = {},
          -- weekdays = {},
          -- skipdays = {}
        }
      }
    }
  }

  return new
end

local function days_diff(d1, d2)
  local t1, t2 = os.time(d1), os.time(d2)
  local diff = math.floor(
    os.difftime(t1, t2) / (24 * 60 * 60)
  )
  return diff
end

function reminder:is_on_date(r, date)
  local lists, addendum =
    r.constraints.date.lists,
    r.constraints.date.addendum

  date.hour, date.min, date.sec = 0, 0, 0

  local matcher = {
    days = date.day,
    months = date.month,
    years = date.year,
    weekdays = tonumber(os.date('%w', os.time(date)))
  }

  local fulfilled = true -- default occurance

  for k, list in pairs(lists) do -- truth checking
    if next(list) then
      if k ~= 'skipdays' and addendum[k] then
        local micro_fulfilled = false
  
        for n in pairs(list) do
          if n == matcher[k] then
            micro_fulfilled = true
          end
        end
  
        fulfilled = fulfilled and micro_fulfilled
      end
    end
  end

  for k, list in pairs(lists) do -- false checking
    if next(list) then
      if k ~= 'skipdays' and not addendum[k] then
        local micro_fulfilled = true
  
        for n in pairs(list) do
          if n == matcher[k] then
            micro_fulfilled = false
          end
        end
  
        fulfilled = fulfilled and micro_fulfilled
      end
    end
  end

  if next(lists.skipdays) then
    local diff_days = days_diff(date, addendum.skip_ref)

    local micro_fulfilled = false

    if diff_days >= 0 then
    
      for n, s in pairs(lists.skipdays) do
        if s and diff_days % n == 0 then
          micro_fulfilled = true
          break
        end
      end

      for n, s in pairs(lists.skipdays) do
        if not s and diff_days % n == 0 then
          micro_fulfilled = false
          break
        end
      end
    end

    fulfilled = fulfilled and micro_fulfilled
  end



  return fulfilled
end

function reminder:create(params)
  local now = os.date('*t')

  params = params or {}
  local new = {
    id = params.id or id(), -- either given or add. id.repo... will not get more ids if we pass an id like this.
    message = params.message,
    created_on = params.created_on or os.time(now),
    last_modified_on = os.time(now),
    state = reminder.states.upcoming,
    time = {
      hour = params.time.hour,
      min = params.time.min,
      sec = params.time.sec
    },
    constraints = {
      -- event = {
      --   completed = {},
      --   pending = {},
      --   ongoing = {},
      --   upcoming = {}
      -- },
      date = {
        addendum = {
          days = params.constraints.date.addendum.days,
          months = params.constraints.date.addendum.months,
          years = params.constraints.date.addendum.years,
          weekdays = params.constraints.date.addendum.weekdays,
          skip_ref = {
            day = params.constraints.date.addendum.skip_ref.day,
            month = params.constraints.date.addendum.skip_ref.month,
            year = params.constraints.date.addendum.skip_ref.year,
            sec = params.constraints.date.addendum.skip_ref.sec,
            min = params.constraints.date.addendum.skip_ref.min,
            hour = params.constraints.date.addendum.skip_ref.hour,
          },
        },
        lists = {
          days = {},
          months = {},
          years = {},
          weekdays = {},
          skipdays = {},
        }
      }
    }
  }

  local lists = params.constraints.date.lists
  local new_lists = new.constraints.date.lists

  for k, list in pairs(lists) do
    for n, s in pairs(list) do
      new_lists[k][n] = s
    end
  end

  return new
end

-----------------------------------
-- TESTING AREA

-- local t = {day = 22, month = 9, year = 2021}

-- print(reminder:is_on_date(reminder:create_dummy(), t))

-----------------------------------

return reminder