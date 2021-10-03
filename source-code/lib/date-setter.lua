local vec2d = require('lib.vec2d')
local lume = require('lib.lume')
local focus = require('lib.focus')

local u = require('lib.utility')

local date_setter = {}

local font, theme,

  offset, border, month_limit,

  widths
  
  month_limit = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  
  local function max_days(month, year)
    if month == 2 and (year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)) then
      return 29
    end
      return month_limit[month]
  end

function date_setter:init(params)
  font = params.theme.font
  theme = params.theme
  
  offset = 0
  border = 2
  
  widths = {
    day = font:getWidth('xx'),
    month = font:getWidth('xx'),
    year = font:getWidth('xxxx'),
  }

  date_setter.focus = focus:init({
    'day',
    'month',
    'year'
  })
end

local function set_offset()
  if date_setter.focus() == 'day' then
    offset = 0
  elseif date_setter.focus() == 'month' then
    offset = font:getWidth('xx/')
  elseif date_setter.focus() == 'year' then
    offset = font:getWidth('xx/xx/')
  end
end

function date_setter:update_message()
  date_setter.text = os.date('%d/%m/%Y', os.time({
    hour = date_setter.data.hour,
    min = date_setter.data.min,
    sec = date_setter.data.sec,
    day = date_setter.data.day,
    month = date_setter.data.month,
    year = date_setter.data.year
  }))
  set_offset()
end

function date_setter:create(params)
  date_setter.pos = vec2d{
    x = params.pos and params.pos.x or 100,
    y = params.pos and params.pos.y or 100,
  }

  date_setter.data = params.data
  date_setter:update_message()

  return date_setter
end

function date_setter:draw(outline_active)
  love.graphics.setColor(u.t_c(theme.font_color))
  love.graphics.print(date_setter.text, date_setter.pos.x, date_setter.pos.y)

  -- love.graphics.setColor(1, 1, 1, outline_active and 1 or 0)
  love.graphics.setColor(0, 0, 0, outline_active and 1 or 0)
  love.graphics.rectangle(
    'line',
    date_setter.pos.x + offset - border,
    date_setter.pos.y - border,
    widths[date_setter.focus()] + 2 * border,
    font:getHeight() + border
  )
end

function date_setter:keypressed(key)
  if key == 'tab' then
    if love.keyboard.isDown('lshift') then
      date_setter.focus:prev()
    else
      date_setter.focus:next()
    end
  end
  set_offset()
end

function date_setter:wheelmoved(x, y)
  local shift = 1

  if y < 0 then

    if love.keyboard.isDown('lshift') then
      shift = 5
    end

    if date_setter.focus() == 'day' then
      date_setter.data.day = lume.wrap(date_setter.data.day + shift, 1, max_days(date_setter.data.month, date_setter.data.year))
    elseif date_setter.focus() == 'month' then
      date_setter.data.month = lume.wrap(date_setter.data.month + 1, 1, 12)
    elseif date_setter.focus() == 'year' then
      date_setter.data.year = lume.wrap(date_setter.data.year + shift, 2021, 2220)
    end
  elseif y > 0 then

    if love.keyboard.isDown('lshift') then
      shift = 5
    end

    if date_setter.focus() == 'day' then
      date_setter.data.day = lume.wrap(date_setter.data.day - shift, 1, max_days(date_setter.data.month, date_setter.data.year))
    elseif date_setter.focus() == 'month' then
      date_setter.data.month = lume.wrap(date_setter.data.month - 1, 1, 12)
    elseif date_setter.focus() == 'year' then
      date_setter.data.year = lume.wrap(date_setter.data.year - shift, 2021, 2220)
    end
  end
  date_setter:update_message()
end

return date_setter