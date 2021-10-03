local vec2d = require('lib.vec2d')

local u = require('lib.utility')

local progress_bar = {
  margin = 5
}
local font, theme, anim

function progress_bar:init(params)
  font = params.theme.font
  theme = params.theme
  anim = params.anim
end

function progress_bar:create(params)
  params = params or {}

  progress_bar.pos = vec2d{
    x = params.pos and params.pos.x or 100,
    y = params.pos and params.pos.y or 100,
  }
  progress_bar.dim = vec2d{
    x = params.dim and params.dim.x or 300,
    y = params.dim and params.dim.y or 30,
  }

  progress_bar.percentage = params.percentage or 0

  return progress_bar
end

function progress_bar:draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle(
    'line',
    progress_bar.pos.x,
    progress_bar.pos.y,
    progress_bar.dim.x,
    progress_bar.dim.y,
    3
  )
  
  love.graphics.setColor(1, 1, 1)
  if progress_bar.percentage > 0 then
    love.graphics.rectangle(
      'fill',
      progress_bar.pos.x + progress_bar.margin,
      progress_bar.pos.y + progress_bar.margin,
      progress_bar.percentage * (progress_bar.dim.x - 2 * progress_bar.margin),
      progress_bar.dim.y - 2 * progress_bar.margin,
      3
    )
  end

  love.graphics.setColor(u.t_c(theme.font_color))
  love.graphics.printf(
    string.format('%.1f%%', progress_bar.percentage * 100),
    progress_bar.pos.x + 2 * progress_bar.margin,
    progress_bar.pos.y + (progress_bar.dim.y - font:getHeight()) / 2,
    progress_bar.dim.x - 4 * progress_bar.margin,
    'center'
  )
end

function progress_bar:on_tick(new_perc)
  if progress_bar.percentage ~= new_perc then
    anim:move{
      progress_bar,
      to = {
        percentage = new_perc
      },
      fn = anim.fn.SIN,
      duration = 0.25
    }
  end
end

return progress_bar