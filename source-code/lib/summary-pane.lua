local vec2d = require('lib.vec2d')
local lume  = require('lib.lume')

local u = require('lib.utility')

local summary = {}
local font, theme,

  triple

function summary:init(params)
  font = params.theme.font
  theme = params.theme

  triple = love.graphics.newImage('assets/images/triple.png')
end

function summary:create(params)
  summary.pos = vec2d{
    x = params.pos and params.pos.x or 100,
    y = params.pos and params.pos.y or 100,
  }
  summary.dim = vec2d{
    x = params.dim and params.dim.x or 300,
    y = params.dim and params.dim.y or 400,
  }
  summary.margin = params.margin or 10
  summary:update_reminder(params.reminder)

  return summary
end

function summary:update_reminder(r)
  summary.reminder = r
  if r then
    local w, wrapped_message = font:getWrap(r.message, summary.dim.x - 2 * summary.margin)

    if #wrapped_message > 15 then
      summary.triple_active = true
    else
      summary.triple_active = false
    end
  end
end

function summary:draw()
  love.graphics.rectangle(
    'fill',
    summary.pos.x, summary.pos.y,
    summary.dim.x, summary.dim.y,
    3
  )

  love.graphics.setColor(u.t_c(theme.font_color))
  love.graphics.printf(
    'Summary',
    summary.pos.x + summary.margin,
    summary.pos.y + summary.margin,
    summary.dim.x - 2 * summary.margin,
    'center'
  )

  local c =0.5
  love.graphics.setColor(c, c, c)
  love.graphics.line(
    summary.pos.x + summary.margin,
    summary.pos.y + font:getHeight() + 2 * summary.margin,
    summary.pos.x + summary.dim.x - summary.margin,
    summary.pos.y + font:getHeight() + 2 * summary.margin
  )

  if summary.reminder then
    love.graphics.setScissor(
      summary.pos.x,
      summary.pos.y + 3 * summary.margin + font:getHeight(),
      summary.dim.x,
      15 * font:getHeight()
    )

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      summary.reminder.message,
      summary.pos.x + summary.margin,
      summary.pos.y + font:getHeight() + 3 * summary.margin,
      summary.dim.x - 2 * summary.margin
    )

    love.graphics.setScissor()

    love.graphics.setColor(1, 1, 1)
    if summary.triple_active then
      love.graphics.draw(
        triple,
        summary.pos.x + summary.dim.x - (summary.margin + triple:getWidth()),
        summary.pos.y + 3 * summary.margin + (15 + 1) * font:getHeight()
      )
    end

    local t = summary.reminder.time
    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.print(
      string.format(
        'At: %.2d:%.2d %s',
        lume.wrap(t.hour, 1, 12),
        t.min,
        t.hour > 11 and 'PM' or 'AM'
      ),
      summary.pos.x + summary.margin,
      summary.pos.y + 5 * summary.margin + (15 + 1) * font:getHeight()
    )
  end
end

return summary