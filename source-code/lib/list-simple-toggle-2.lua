local vec2d = require('lib.vec2d')
local lume = require('lib.lume')
local u = require('lib.utility')

local list = {}
list.__index = list

local font, theme

local state_to_c = {
  0.85,
  1,
  0,
}

function list:init(params)
  font = params.theme.font
  theme = params.theme
end

function list:create(params)
  local new = setmetatable({
    items = {},
    grade = params.grade or 10,
    offset = 0,
    margin = params.margin or 5,
    translator = params.translator or {},
    pos = vec2d{
      x = (params.pos and params.pos.x) and params.pos.x or 100,
      y = (params.pos and params.pos.y) and params.pos.y or 100,
    },
    dim = vec2d{
      x = (params.dim and params.dim.x) and params.dim.x or 100,
      y = (params.dim and params.dim.y) and params.dim.y or 100,
    }
  }, list)

  for _, item in pairs(params.reference) do
    new.items[item] = 1
  end

  new.item_dim = vec2d{
    x = (params.item_dim and params.item_dim.x) and params.item_dim.x or new.dim.x - 2 * new.margin,
    y = (params.item_dim and params.item_dim.y) and params.item_dim.y or 30,
  }

  return new
end

function list:draw()

  love.graphics.setScissor(
    self.pos.x,
    self.pos.y + self.margin,
    self.dim.x,
    self.dim.y - 2 * self.margin
  )

  local i = 0
  for item, state in pairs(self.items) do
    local x, y =
      self.pos.x + self.margin,
      self.pos.y + self.margin + i * (self.item_dim.y + self.margin) - self.offset

    love.graphics.setColor(0, 0, 0)
    local border = 1
    love.graphics.rectangle(
      'line',
      x + border, y + border,
      self.item_dim.x - 2 * border,
      self.item_dim.y - 2 * border
    )

    local c = state_to_c[state]
    love.graphics.setColor(c, c, c)
    love.graphics.rectangle(
      'fill',
      x + border, y + border,
      self.item_dim.x - 2 * border,
      self.item_dim.y - 2 * border
    )

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      self.translator[item] and self.translator[item] or item,
      x,
      y + (self.item_dim.y - font:getHeight()) / 2,
      self.item_dim.x,
      'center'
    )

    i = i + 1
  end

  love.graphics.setScissor()
end

function list:max_offset()
  local n = lume.count(self.items)
  return (n + 1) * self.margin +
  (n * self.item_dim.y) - self.dim.y
end

function list:scroll(y)
  local max_offset = self:max_offset()
  if max_offset > 0 then
    if y > 0 then
      if love.keyboard.isDown('lshift') then
        self.offset = self.offset - 5 * self.grade
      else
        self.offset = self.offset - self.grade
      end
    elseif y < 0 then
      if love.keyboard.isDown('lshift') then
        self.offset = self.offset + 5 * self.grade
      else
        self.offset = self.offset + self.grade
      end
    end
    self.offset = lume.clamp(self.offset, 0, self:max_offset())
  end
end

function list:reset()
  for item in pairs(self.items) do
    self.items[item] = 1
  end
end

function list:clicked_on(x, y, button)
  local cursor = {x = x, y = y}

  local i = 0
  for item, state in pairs(self.items) do
    
    local item_box = {
      pos = {
        x = self.pos.x + self.margin,
        y = self.pos.y + self.margin + i * (self.item_dim.y + self.margin) - self.offset
      },
      dim = self.item_dim
    }
    if u.collides(cursor, item_box) then
      if button == 1 then
        self.items[item] = lume.wrap(state + 1, 1, 3)
      elseif button == 2 then
        self.items[item] = lume.wrap(state - 1, 1, 3)
      end
      if self.translator[item] then
        return item, self.translator[item], self.items[item]
      else
        return item, item, self.items[item]
      end
    end

    i = i + 1
  end
end

return list