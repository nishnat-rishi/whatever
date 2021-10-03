local u = require('lib.utility')
local vec2d = require('lib.vec2d')
local lume = require('lib.lume')

local font, theme,
  timer,

  border,
  blinker

local typer = {
  message = '',
  pos = nil,
  dim = nil
}

function typer:init(params)
  timer = params.timer
  font = params.theme.font
  theme = params.theme

  love.keyboard.setKeyRepeat(true)

  border = 5

  typer.scroll_offset = 0
  typer.velocity = 0
  typer.slowdown = 20

  blinker = {
    offset_pos = {
      x = 0, y = 0
    },
    dim = {
      x = font:getWidth(' '), y = font:getHeight()
    },
    color = {
      0, 0, 0, 1
    }
  }

  timer:create{
    id = blinker,
    on_end = function ()
      blinker.color[4] = (blinker.color[4] + 1) % 2
    end,
    duration = 0.5,
    periodic = true
  }
end

local function update_blinker()

  local width, wrapped_message = font:getWrap(
    typer.data.message, typer.dim.x - border * 2
  )

  if #typer.data.message > 0 and string.sub(typer.data.message, -1, -1) == '\n' then
    wrapped_message[#wrapped_message + 1] = ''
  end

  if #wrapped_message > 0 then
    blinker.offset_pos.x = font:getWidth(
      wrapped_message[#wrapped_message]
    )
  else
    blinker.offset_pos.x = 0
  end
  blinker.offset_pos.y = font:getHeight() * math.max(0, (#wrapped_message - 1))

  blinker.color[4] = 1
  timer:reset(blinker)
end

function typer:update_message(message)
  typer.data.message = message
  update_blinker()
end

function typer:create(params)
  typer.pos = vec2d{
    x = params.pos and params.pos.x or 100,
    y = params.pos and params.pos.y or 100
  }

  typer.dim = vec2d{
    x = params.dim and params.dim.x or 300,
    y = params.dim and params.dim.y or 200
  }

  typer.data = params.data

  typer:update_message(typer.data.message or '')

  return typer
end

function typer:draw(blinker_active)

  -- big box
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle(
    'fill',
    typer.pos.x, typer.pos.y,
    typer.dim.x, typer.dim.y,
    5
  )

  love.graphics.setScissor(
    typer.pos.x + border, typer.pos.y + border,
    typer.dim.x - border * 2, typer.dim.y - border * 2
  )

  -- words
  love.graphics.setColor(u.t_c(theme.font_color))
  love.graphics.printf(
    typer.data.message, 
    typer.pos.x + border,
    typer.pos.y + border,
    typer.dim.x - border * 2,
    'left'
  )

  love.graphics.setScissor()

  local blinker_color = blinker_active and blinker.color or {1, 1, 1, 0}
  love.graphics.setColor(u.t_c(blinker_color))
  love.graphics.rectangle(
    'fill',
    typer.pos.x + border + blinker.offset_pos.x,
    typer.pos.y + border + blinker.offset_pos.y,
    blinker.dim.x, blinker.dim.y,
    1
  )
end

function typer:keypressed(key)
  if key == 'backspace' and #typer.data.message > 0 then
    if love.keyboard.isDown('lctrl') then
      local i = -1
      local found
      found = string.find(typer.data.message, '%s', i)
      while #typer.data.message + i > 0 and not found do
        i = i - 1
        found = string.find(typer.data.message, '%s', i)
      end
      typer:update_message(string.sub(typer.data.message, 1, i - 1))
    else
      typer:update_message(string.sub(typer.data.message, 1, -2))
    end
  elseif key == 'return' then
    if not love.keyboard.isDown('lctrl') then
      typer:update_message(typer.data.message .. '\n')
    end
  end
end

function typer:textinput(t)
  typer:update_message(typer.data.message .. t)
end

return typer
------------------------------------------------------