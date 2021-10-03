local vec2d = require('lib.vec2d')
local lume = require('lib.lume')
local focus = require('lib.focus')

local u = require('lib.utility')

local time_setter = {}

local font, theme,

  offset, border

function time_setter:init(params)
  font = params.theme.font
  theme = params.theme
  
  offset = 0
  border = 2

  time_setter.focus = focus:init({
    'hour',
    'min',
    'meridian'
  })
end

local function set_offset()
  if time_setter.focus() == 'hour' then
    offset = 0
  elseif time_setter.focus() == 'min' then
    offset = font:getWidth('00:')
  elseif time_setter.focus() == 'meridian' then
    offset = font:getWidth('00:00 ')
  end
end

function time_setter:update_message()
  time_setter.text = os.date('%I:%M %p', os.time({
    year = 2021, month = 1, day = 1,
    hour = time_setter.data.hour, min = time_setter.data.min, sec = time_setter.data.sec
  }))
  set_offset()
end

function time_setter:create(params)
  time_setter.pos = vec2d{
    x = params.pos and params.pos.x or 100,
    y = params.pos and params.pos.y or 100,
  }

  time_setter.data = params.data
  time_setter:update_message()

  if time_setter.focus() == 'hour' then
    offset = 0
  elseif time_setter.focus() == 'min' then
    offset = font:getWidth('00:')
  elseif time_setter.focus() == 'meridian' then
    offset = font:getWidth('00:00 ')
  end
  
  return time_setter
end

function time_setter:draw(outline_active)
  love.graphics.setColor(u.t_c(theme.font_color))
  love.graphics.print(time_setter.text, time_setter.pos.x, time_setter.pos.y)

  -- love.graphics.setColor(1, 1, 1, outline_active and 1 or 0)
  love.graphics.setColor(0, 0, 0, outline_active and 1 or 0)
  love.graphics.rectangle(
    'line',
    time_setter.pos.x + offset - border,
    time_setter.pos.y - border,
    font:getWidth('xx') + 2 * border,
    font:getHeight() + border
  )
end

function time_setter:keypressed(key)
  if key == 'tab' then
    if love.keyboard.isDown('lshift') then
      time_setter.focus:prev()
    else
      time_setter.focus:next()
    end
  end
  set_offset()
end

function time_setter:wheelmoved(x, y)
  local shift = 1

  if y < 0 then

    if love.keyboard.isDown('lshift') then
      shift = lume.wrap(5 - time_setter.data.min % 5, 1, 5)
    end

    if time_setter.focus() == 'hour' then
      time_setter.data.hour = lume.wrap(time_setter.data.hour + 1, 0, 23)
    elseif time_setter.focus() == 'min' then
      time_setter.data.min = lume.wrap(time_setter.data.min + shift, 0, 59)
    elseif time_setter.focus() == 'meridian' then
      time_setter.data.hour = lume.wrap(time_setter.data.hour + 12, 0, 23)
    end
  elseif y > 0 then

    if love.keyboard.isDown('lshift') then
      shift = lume.wrap(time_setter.data.min % 5, 1, 5)
    end

    if time_setter.focus() == 'hour' then
      time_setter.data.hour = lume.wrap(time_setter.data.hour - 1, 0, 23)
    elseif time_setter.focus() == 'min' then
      time_setter.data.min = lume.wrap(time_setter.data.min - shift, 0, 59)
    elseif time_setter.focus() == 'meridian' then
      time_setter.data.hour = lume.wrap(time_setter.data.hour - 12, 0, 23)
    end
  end
  time_setter:update_message()
end

return time_setter