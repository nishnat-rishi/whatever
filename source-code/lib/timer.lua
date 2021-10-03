local timer = {
  ids = {}, 
  duration = {}, 
  remaining = {}, 
  on_end = {}, 
  periodic = {},
  paused = {},
  _trash = {},
  _pendingRegistrations = {},
}

function timer:create(params) -- {id, duration, on_end, periodic}
  assert(params.id, '\'id\' field is required during timer registration.')
  self._pendingRegistrations[params.id] = params
end

function timer:pause(id)
  self.paused[id] = true
end

function timer:play(id)
  self.paused[id] = false
end

function timer:reset(id)
  self.remaining[id] = self.duration[id]
end

function timer:purge(id)
  self._trash[id] = true
end

function timer:update(dt)
  for id in pairs(self.ids) do
    if not self.paused[id] then
      if self.remaining[id] > 0 then
        self.remaining[id] = self.remaining[id] - dt
      else
        self.on_end[id]()
        if self.periodic[id] then
          self.remaining[id] = self.duration[id]
        else
          self:purge(id)
        end
      end
    end
  end
  if next(self._trash) then -- *5
    self:_clear()
  end
  if next(self._pendingRegistrations) then
    self:_registerPending()
  end
end

function timer:_rawRegister(params)
  self.ids[params.id] = true
  self.duration[params.id] = params.duration
  self.remaining[params.id] = params.duration
  self.on_end[params.id] = params.on_end
  self.periodic[params.id] = params.periodic
end

function timer:_clear()
  for id, _ in pairs(self._trash) do
    self.ids[id] = nil
    self.duration[id] = nil
    self.remaining[id] = nil
    self.on_end[id] = nil
    self.periodic[id] = nil
    self._trash[id] = nil -- *2
  end
end

function timer:_registerPending()
  for id, params in pairs(self._pendingRegistrations) do
    self:_rawRegister(params)
    self._pendingRegistrations[id] = nil
  end
end

return timer

--------------------
----- COMMENTS -----
--------------------

--[[ 
*1: One performance increasing change can be to give the user the ability to
    dispose of the timer instead of it happening automatically. This runs the
    risk of unwary users not handling disposal at all and thus letting the 
    memory cost go ham. But it also affords careful users the opportunity to
    optimize their code.
*2: The iterator maintains its own state, so we can safely assign nil to 
    self._trash[id].
*3: Rethink the implications of 'self.ids[params.id] = true' and perhaps see 
    what deep changes are in order (instead of just a naive refactoring i.e. 
    loop conversions and minor assignment changes).
    Potential (brainstormed) implications:
    - Trashcans become trivial. (Somehow no trashcan would be required, simply
      assign self.ids[id] = nil and the pairs loop will keep on chugging along)
    - A separate _pendingRegistrations table is unnecessary! Simply overwrite.
      (But this may cause race conditions within the update-for-loop! So think
      this decision through carefully.)
*4: params = {id, duration, on_end, periodic}
*5: Optimization trick. We won't call self._clear() till there is something to
    clear! This reduces one function call (in a function which is called 60
    times a second!)
    
*6: If the ID is already taken, just attach the current params onto a 'pending'
    registrations table. After the update loop is finished and trash is cleared,
    items from this pending table will be registered onto the existing id.
--]]