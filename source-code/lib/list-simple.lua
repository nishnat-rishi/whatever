local vec2d = require('lib.vec2d')
local lume = require('lib.lume')
local u = require('lib.utility')

local list = {}
list.__index = list

local font, theme

function list:init(params)
  font = params.theme.font
  theme = params.theme
end

function list:create(params)
  local new = setmetatable({
    items = params.items or {},
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

  new.item_dim = vec2d{
    x = (params.item_dim and params.item_dim.x) and params.item_dim.x or new.dim.x - 2 * new.margin,
    y = (params.item_dim and params.item_dim.y) and params.item_dim.y or 30,
  }

  return new
end

function list:draw(p)
  love.graphics.setScissor(
    self.pos.x,
    self.pos.y + self.margin,
    self.dim.x,
    self.dim.y - 2 * self.margin
  )

  local i = 0
  for k, item in pairs(self.items) do
    local x, y =
      self.pos.x + self.margin,
      self.pos.y + self.margin + i * (self.item_dim.y + self.margin) - self.offset


    local border = 1
    local c = p and 1 or 0
    love.graphics.setColor(c, c, c)
    love.graphics.rectangle(
      'fill',
      x + border, y + border,
      self.item_dim.x - 2 * border,
      self.item_dim.y - 2 * border
    )

    local b_c = p and 0 or 1
    love.graphics.setColor(b_c, b_c, b_c)
    love.graphics.rectangle(
      'line',
      x + border, y + border,
      self.item_dim.x - 2 * border,
      self.item_dim.y - 2 * border
    )

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      self.translator[k] and self.translator[k] or k,
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

function list:clicked_on(x, y)
  local cursor = {x = x, y = y}

  local i = 0
  for k, item in pairs(self.items) do
    
    local item_box = {
      pos = {
        x = self.pos.x + self.margin,
        y = self.pos.y + self.margin + i * (self.item_dim.y + self.margin) - self.offset
      },
      dim = self.item_dim
    }
    if u.collides(cursor, item_box) then
      return item
    end
    i = i + 1
  end
end

return list