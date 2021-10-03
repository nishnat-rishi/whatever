local vec2d = require('lib.vec2d')
local lume = require('lib.lume')
local u = require('lib.utility')
local reminder = require('lib.reminder')

local list = {}
list.__index = list

local font, theme

function list:init(params)
  font = params.theme.font
  theme = params.theme
end

function list:update_wrapped()
  for i, item in ipairs(self.internal_list) do
    local _, w = font:getWrap(
      item.message,
      self.item_dim.x - 2 * self.text_margin
    )
    self.wrapped[i] = w[1]
  end
end

function list:create(params)
  local new = setmetatable({
    data = params.data,
    state = params.state,
    wrapped = {},
    internal_list = {},

    opacity = params.opacity or 1,
    user_on_tick = params.on_tick or function () end,
    user_update_wrapped = params.update_wrapped or list.update_wrapped,
    offset = 0,
    grade = params.grade or 10,
    margin = params.margin or 5,
    text_margin = params.text_margin or 10,
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

  new:on_tick()

  return new
end

function list:draw()

  love.graphics.setScissor(
    self.pos.x,
    self.pos.y + self.margin,
    self.dim.x,
    self.dim.y - 2 * self.margin
  )

  for i, item in ipairs(self.internal_list) do
      local x, y =
        self.pos.x + self.margin,
        self.pos.y + self.margin + (i-1) * (self.item_dim.y + self.margin) - self.offset

      local border = 1
      local c = (self.active and self.active == item.id) and 1 or 0.85

      local a = self.opacity
      love.graphics.setColor(c, c, c, a)
      love.graphics.rectangle(
        'fill',
        x + border, y + border,
        self.item_dim.x - 2 * border,
        self.item_dim.y - 2 * border
      )

      love.graphics.setColor(0, 0, 0, a)
      love.graphics.rectangle(
        'line',
        x + border, y + border,
        self.item_dim.x - 2 * border,
        self.item_dim.y - 2 * border
      )

      local r, g, b = u.t_c(theme.font_color)
      love.graphics.setColor(r, g, b, a)
      love.graphics.printf(
        self.wrapped[i],
        x + self.text_margin,
        y + (self.item_dim.y - font:getHeight()) / 2,
        self.item_dim.x - 2 * self.text_margin,
        'left'
      )
  end

  love.graphics.setScissor()
end

function list:on_tick()
  self:user_on_tick()
  self:user_update_wrapped()
end

function list:max_offset()
  local n = #self.internal_list
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
  else
    self.offset = 0
  end
end

function list:clicked_on(x, y)
  local cursor = {x = x, y = y}
  for i, item in ipairs(self.internal_list) do
    local item_box = {
      pos = {
        x = self.pos.x + self.margin,
        y = self.pos.y + self.margin + (i-1) * (self.item_dim.y + self.margin) - self.offset
      },
      dim = self.item_dim
    }
    if u.collides(cursor, item_box) then
      self.active = item.id
      return item.id, item
    end
  end
  self.active = nil
end

return list