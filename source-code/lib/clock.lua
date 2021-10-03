local vec2d = require('lib.vec2d')
local u = require('lib.utility')

local clock = {
  margin = 5
}
local font, theme

function clock:init(params)
  font = params.theme.font
  theme = params.theme
end

function clock:create(params)
  params = params or {}

  local sample_text = '17th Sep(09) 2021 - 08:48:40 PM - Fri'

  clock.pos = vec2d{
    x = params.pos and params.pos.x or 100,
    y = params.pos and params.pos.y or 100,
  }
  clock.dim = vec2d{
    x = params.dim and params.dim.x or font:getWidth(sample_text) + clock.margin,
    y = params.dim and params.dim.y or 30,
  }

  clock.text = '-'

  return clock
end

function clock:draw()
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle(
    'line',
    clock.pos.x,
    clock.pos.y,
    clock.dim.x,
    clock.dim.y,
    3
  )

  love.graphics.setColor(u.t_c(theme.font_color))
  love.graphics.printf(
    clock.text,
    clock.pos.x + clock.margin,
    clock.pos.y + (clock.dim.y - font:getHeight()) / 2,
    clock.dim.x - 2 * clock.margin,
    'center'
  )
end

function clock:on_tick(time)
  local day = tonumber(os.date('%d', time))
  local suff = u.num_suffix(day)
  clock.text = string.format(
    '%.2d%s %s',
    day, suff,
    os.date('%b(%m) %Y - %I:%M:%S %p - %a', time)
  )
end

return clock