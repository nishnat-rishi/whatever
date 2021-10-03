local utility = {}

function utility.setDigitalFont()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  local font = love.graphics.newImageFont("assets/images/image-font-actual.png",
  " abcdefghijklmnopqrstuvwxyz" ..
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
  "123456789.,!?-+/():;%&`'*#=[]\"{}<>_")

  love.graphics.setFont(font)
  return font
end

function utility.setFont(font, hinting)
  love.graphics.setDefaultFilter('nearest', 'nearest')
  local val = love.graphics.newFont(font, hinting)
  love.graphics.setFont(val)
  return val
end

function utility.c(r, g, b, a)
  return r / 255, g / 255, b / 255, a
end

function utility.t_c(t)
  return t[1] / 255, t[2] / 255, t[3] / 255, t[4]
end

function utility.dummy(n)
  local d = {}
  for i = 1, n  do
    d[i] = tostring(n)
  end
  return d
end

function utility.dummy_boxes(n, dim)
  local d = {}
  for i = 1, n  do
    d[i] = {
      message = i,
      pos = {x = 0, y = 0},
      dim = dim
    }
  end
  return d
end



function utility.len(l)
  if not next(l) then
    return 0
  else
    local k = nil
    local s = -1
    repeat
      k = next(l, k)
      s = s + 1
    until k == nil
    return s
  end
end

function utility.collides(pos, obj)
  return pos.x >= obj.pos.x and
  pos.x <= obj.pos.x + obj.dim.x and
  pos.y >= obj.pos.y and
  pos.y <= obj.pos.y + obj.dim.y
end

function utility.collides_aop(pos, obj)
  return pos.x >= obj.anchor.x + obj.offset.x and
  pos.x <= obj.anchor.x + obj.offset.x + obj.dim.x and
  pos.y >= obj.anchor.y + obj.offset.y and
  pos.y <= obj.anchor.y + obj.offset.y + obj.dim.y
end

function utility.collides_y(pos, obj)
  return pos.y >= obj.pos.y and pos.y <= obj.pos.y + obj.dim.y
end

function utility.normalize(r, g, b, a)
  return r / 255, g / 255, b / 255, a and a / 255 or 1
end

function utility.days_diff_t(t1, t2)
  local diff = math.floor(
    os.difftime(t1, t2) / (24 * 60 * 60)
  )
  return diff
end

local function table_string(t)
  local s = '{'
  for k, item in pairs(t) do
    if type(item) == 'table' then
      s = s .. string.format('%s=%s', k, table_string(item))
    else
      s = s .. string.format('%s=%s', k, item)
    end
    if next(t, k) then
      s = s .. ', '
    end
  end
  s = s .. '}'
  return s
end
utility.table_string = table_string

function utility.debug_values(t)
  local s = ''
  for k, v in pairs(t) do
    s = s .. string.format('%s: %.2f\n', k, v)
  end
  
  return s
end

function utility.num_suffix(num)
  local ones, tens = num % 10, math.floor((num % 100) / 10)
  if tens ~= 1 then
    if ones == 1 then
      return 'st'
    elseif ones == 2 then
      return 'nd'
    elseif ones == 3 then
      return 'rd'
    end
  end
  return 'th'
end
function utility.diff_string(diff)
  local h, m
  local prefix = ' '
  if diff < 0 then
    diff = -diff
    prefix = '-'
  end
    h, m = math.floor(diff / (60 * 60)), math.floor(diff / 60) % 60

    return string.format('%s%.2d:%.2d', prefix, h, m)
end

return utility