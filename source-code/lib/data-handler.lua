local lume = require('lib.lume')
local reminder = require('lib.reminder')

local data_handler = {}

local order = {
  'id',
  'created_on',
  'last_modified_on',
  'state',
  'time',

  'addendum',
  'skip_ref',

  'days',
  'months',
  'years',
  'weekdays',
  'skipdays',

  'message'
}

local lists_order = {
  'days',
  'months',
  'years',
  'weekdays'
}

--[[
[X] \a: Bell
[X] \b: Backspace
[X] \f: Form feed
[X] \n: Newline
[X] \r: Carriage return
[X] \t: Tab
[X] \v: Vertical tab
[X] \\: Backslash
[X] \": Double quote
[X] \': Single quote
[X] \nnn: Octal value (nnn is 3 octal digits)
[X] \xNN: Hex value (Lua5.2/LuaJIT, NN is two hex digits)
]]

local function date_decompose(date)
  return string.format(
    '%.2d,%.2d,%.4d',
    date.day, date.month, date.year
  )
end

local function date_recompose(raw_date)
  local date = {hour = 0, min = 0, sec = 0}
  date.day, date.month, date.year = string.match(raw_date, '(%d+),(%d+),(%d+)')
  date.day, date.month, date.year = tonumber(date.day), tonumber(date.month), tonumber(date.year)
  return date
end

local function time_decompose(time)
  return string.format(
    '%.2d,%.2d,%.2d',
    time.hour, time.min, time.sec
  )
end

local function time_recompose(raw_time)
  local time = {}
  time.hour, time.min, time.sec = string.match(raw_time, '(%d+),(%d+),(%d+)')
  time.hour, time.min, time.sec = tonumber(time.hour), tonumber(time.min), tonumber(time.sec)
  return time
end

local function addendum_decompose(a)
  return string.format(
    '%d%d%d%d',
    a.days and 1 or 0,
    a.months and 1 or 0,
    a.years and 1 or 0,
    a.weekdays and 1 or 0
  )
end

local function addendum_recompose(raw_a)
  local addendum = {}

  local trans = {
    [0] = false,
    [1] = true
  }

  addendum.days, addendum.months, addendum.years, addendum.weekdays =
    string.match(raw_a, '(%d)(%d)(%d)(%d)')

  for k, s in pairs(addendum) do
    addendum[k] = trans[tonumber(s)]
  end

  return addendum
end

local function lists_decompose(lists)

  local s = ''

  for _, k in ipairs(lists_order) do
    local m_s = ''
    
    for n in pairs(lists[k]) do
      if not next(lists[k], n) then
        m_s = m_s .. string.format('%.2d ', n)
      else
        m_s = m_s .. string.format('%.2d,', n)
      end
    end

    if m_s == '' then
      m_s = '- '
    end

    s = s .. m_s
  end

  return s
end

local function list_recompose(raw_list)
  local list = {}

  if raw_list ~= '-' then
    for n in string.gmatch(raw_list, '(%d+)') do
      list[tonumber(n)] = true
    end
  end

  return list
end

local function string_decompose(s)
  local new_s = string.format("%q", s)
  new_s = new_s:gsub("\\\n", "\\^13") -- \n
  new_s = new_s:gsub("\\9", "\\^9") -- \t

  return new_s
end

local function string_recompose(raw_s)
  local new_s = raw_s
  new_s = new_s:gsub("\\^13", "\n") -- \n
  new_s = new_s:gsub("\\^9", "\t") -- \n
  new_s = new_s:gsub("\\\\", "\\") -- \t
  new_s = new_s:gsub('\\"', '"') -- \t
  new_s = new_s:gsub("\\'", "'") -- \t
  -- new_s = new_s:gsub("\\", "\\09") -- \t

  return new_s
end

local function skipdays_decompose(skipdays)
  local s = ''
  for n, state in pairs(skipdays) do
    if not next(skipdays, n) then
      s = s .. string.format('%.2d:%d ', n, state and 1 or 0)
    else
      s = s .. string.format('%.2d:%d,', n, state and 1 or 0)
    end
  end

  if s == '' then
    return '- '
  end

  return s
end

local function skipdays_recompose(raw_skipdays)
  local skipdays = {}

  local trans = {
    [0] = false,
    [1] = true
  }

  if raw_skipdays  ~= '-' then
    for n, s in string.gmatch(raw_skipdays, '(%d+):(%d)') do
      skipdays[tonumber(n)] = trans[tonumber(s)]
    end
  end

  return skipdays
end

function data_handler:decompose(r)
  local s = string.format(
    '%s %d %d %d %s %s %s %s%s%s',
    r.id,
    r.created_on,
    r.last_modified_on,
    r.state,
    time_decompose(r.time),

    addendum_decompose(r.constraints.date.addendum),
    date_decompose(r.constraints.date.addendum.skip_ref),

    lists_decompose(r.constraints.date.lists),
    skipdays_decompose(r.constraints.date.lists.skipdays),
    string_decompose(r.message)
  )

  return s
end

function data_handler:recompose(raw_r)
  local r = reminder:create_empty()

  local m_pos = string.find(raw_r, "\"")
  
  local portions = lume.split(string.sub(raw_r, 1, m_pos - 2))
  
  r.id = portions[1]
  r.created_on = tonumber(portions[2])
  r.last_modified_on = tonumber(portions[3])
  r.state = tonumber(portions[4])
  
  r.time = time_recompose(portions[5])
  r.constraints.date.addendum = addendum_recompose(portions[6])
  r.constraints.date.addendum.skip_ref = date_recompose(portions[7])
  
  for i, k in ipairs(lists_order) do
    r.constraints.date.lists[k] = list_recompose(portions[7 + i])
  end -- till portions[11]
  
  r.constraints.date.lists.skipdays = skipdays_recompose(portions[12])
  
  local message = string.sub(raw_r, m_pos + 1, #raw_r - 1)
  r.message = string_recompose(message)

  return r
end

function data_handler:archive(r)
  local s = string.format(
    '%d %d %d %s %s %s %s%s%s',
    r.created_on,
    r.last_modified_on,
    r.state,
    time_decompose(r.time),

    addendum_decompose(r.constraints.date.addendum),
    date_decompose(r.constraints.date.addendum.skip_ref),

    lists_decompose(r.constraints.date.lists),
    skipdays_decompose(r.constraints.date.lists.skipdays),
    string_decompose(r.message)
  )

  return s
end

function data_handler:unarchive(raw_r, id)
  local r = reminder:create_empty()

  local m_pos = string.find(raw_r, "\"")
  
  local portions = lume.split(string.sub(raw_r, 1, m_pos - 2))
  
  r.id = id
  -- r.id = 'abcde12345' -- since archived reminders, when unarchived should mostly be used for viewing purposes only, wasting id()s on it does not make much sense. (unless the unarchiving process also involves reusing old reminders).
  r.created_on = tonumber(portions[1])
  r.last_modified_on = tonumber(portions[2])
  r.state = tonumber(portions[3])
  
  r.time = time_recompose(portions[4])
  r.constraints.date.addendum = addendum_recompose(portions[5])
  r.constraints.date.addendum.skip_ref = date_recompose(portions[6])
  
  for i, k in ipairs(lists_order) do
    r.constraints.date.lists[k] = list_recompose(portions[6 + i])
  end -- till portions[11]
  
  r.constraints.date.lists.skipdays = skipdays_recompose(portions[11])
  
  local message = string.sub(raw_r, m_pos + 1, #raw_r - 1)
  r.message = string_recompose(message)

  return r
end

function data_handler:progress_decompose(progress, date)
  local s = date_decompose(date) .. '\n'

  for k, r in pairs(progress) do
    s = string.format('%s%s\n', s, string_decompose(r.message))
  end

  return s
end

function data_handler:progress_recompose(raw_progress, date)
  local progress = {}
  local t = lume.split(raw_progress)
  local d = date_recompose(t[1])

  local keys, states = {}, {}
  local i = 1
  for id_val in string.gmatch(t[2], '(%w+)') do
    keys[i]= id_val
    i = i + 1
  end
  i = 1
  for state in string.gmatch(t[3], '(%d)') do
    states[i] = state
    i = i + 1
  end

  for idx, k in ipairs(keys) do
    progress[k] = states[idx]
  end

  local r = date_recompose(date)

  return progress, d
end

return data_handler