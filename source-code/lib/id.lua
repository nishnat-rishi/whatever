local id = {
  repository = {}, -- save this for persisting sessions.
  length = 10,
  characters = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
    'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', '0'
  }
}

local t = {
  __call = function(self)
    local instance
      local id_val
      repeat
        instance = {}
        for _ = 1, self.length do
          instance[#instance+1] = 
            self.characters[math.random(#self.characters)]
        end
        id_val = table.concat(instance, '')
      until not self.repository[id_val]
      self.repository[id_val] = true
      return id_val
  end
}
setmetatable(id, t)

return id