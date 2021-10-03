local vec2d = {}
vec2d.__index = vec2d
local some_stuff = {
  __call = function(vec2d, vector)
    if not vector then
      vector = {}
    end
    if not vector.x then
      vector.x = 0
    end
    if not vector.y then
      vector.y = 0
    end
    return setmetatable(vector, vec2d)
  end,
}
setmetatable(vec2d, some_stuff)

function vec2d.__tostring(vector)
  if not vector.x or not vector.y then
    return 'vector has missing fields.'
  end
  return string.format('{x=%f, y=%f}', vector.x, vector.y)
end

function vec2d.__add(v1, v2)
  return setmetatable({x=v1.x+v2.x, y=v1.y+v2.y}, vec2d)
end

function vec2d.__sub(v1, v2)
  return setmetatable({x=v1.x-v2.x, y=v1.y-v2.y}, vec2d)
end

function vec2d.__unm(v)
  v.x, v.y = -v.x, -v.y
  return v
end

function vec2d.s_mul(v, scalar)
  return setmetatable(
    {x = v.x * scalar, y = v.y * scalar},
    vec2d
  )
end

function vec2d.apply(v, f)
  return setmetatable(
    {
      x = v.x * f(math.abs(v.x)) / math.abs(v.x),
      y = v.y * f(math.abs(v.y)) / math.abs(v.y)
    },
    vec2d
  )
end

function vec2d.dist(v1, v2)
  return math.sqrt((v1.x - v2.x)^2 + (v1.y - v2.y)^2)
end

function vec2d.copy_of(v)
  return setmetatable({x=v.x, y=v.y}, vec2d)
end
vec2d.from = vec2d.copy_of -- OFFICIALIZE 'from', DEPRECATE 'copy_of'

function vec2d.mag(v)
  return math.sqrt(v.x^2 + v.y^2)
end

function vec2d.unit(v)
  local mag = v:mag()
  return setmetatable(
    {x = v.x / mag, y = v.y / mag},
    vec2d
  )
end

function vec2d.clamp(v, v_max)
  if v_max.x and math.abs(v.x) >= math.abs(v_max.x) then
    v.x = v.x * v_max.x / math.abs(v.x)
  end
  if v_max.y and math.abs(v.y) >= math.abs(v_max.y) then
    v.y = v.y * v_max.y / math.abs(v.y)
  end
end

function vec2d.__eq(v1, v2)
  return v1.x == v2.x and v1.y == v2.y
end

function vec2d.update(v, v_updator)
  v.x = v_updator.x
  v.y = v_updator.y
end

function vec2d.near(v, v_thres)
  return (v_thres.x and math.abs(v.x) <= v_thres.x or false) or
   (v_thres.y and math.abs(v.y) <= v_thres.y or false)
end

vec2d.zero = vec2d()
vec2d.i = vec2d{x = 1, y = 0}
vec2d.j = vec2d{x = 0, y = 1}

-- Testing area

-- local v = vec2d({x = 20, y = 40})
-- local v2 = vec2d{x = 20, y = 40}
-- print(v ~= v2)

return vec2d