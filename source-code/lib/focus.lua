
local lume = require('lib.lume')

local focus = {}
focus.__index = focus
focus.__call = function(self)
  return self.targets[self.current]
end

function focus:init(targets, current)
  local new = setmetatable(
    {
      targets = targets,
      current = current or 1,
      _reverse_lookup = {}
    },
    focus
  )

  for i, target in ipairs(new.targets) do
    new._reverse_lookup[target] = i
  end

  return new
end

function focus:set(target)
  self.current = self._reverse_lookup[target]
end

function focus:next()
  self.current = lume.wrap(self.current + 1, 1, #self.targets)
end

function focus:prev()
  self.current = lume.wrap(self.current - 1, 1, #self.targets)
end

return focus