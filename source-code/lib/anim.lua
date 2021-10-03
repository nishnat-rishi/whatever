local lume = require('lib.lume')

--[[

  changes

  can attach animations to range shifts.
  we will be reusing a lot of underlying materials (fn, frames),
  we will just have props and attachments

  to-do (ON HOLD*):
    *Below mentioned changes are on hold because we can just replicate
    this behaviour by doing:

      anim:attach(... {100, 700}, fn = SQR);
      anim:attach(... {700, 800}, fn = SQRT);
    
    This additionally takes care of the problem of having different 
    'fn's for different ranges (to ensure smoothness, adjacent animations
    should have co-differentiable (they intertwine smoothy) 'fn's,
    which is not what happens for all animations in a single 
    'anim:attach' call.)

    Additionally, it saves a lot of diffing trouble as well, (since we
    only have a 2-range diff function.)

  description of changes:
  these attachments need to have generalized ranges.
  instead of testing for {1, 2}, it should be an 
  anim:range(1, 2, 3, ...) which is {is_range = true, 1, 2, 3, ...}
  so we can simply t.is_range
  
  and for actually producing animations we have to do
  t[1] <-> t[2], t[2] <-> t[3] ... (#t - 1 times)
  and attach ranges between these.

  from -> {100, 400, 800}, to -> {25, 50, 75}

  i have breakpointed some obvious areas which need changing.

]]

local anim = {
  fn = {
    SPIKE_END = {fn = function(x) return 2^(5*x - 5) end, fn_init = 0, fn_end = 1.2},
    LINE = {fn = function(x) return x end, fn_init = 0, fn_end = 1},
    SIN = {fn = math.sin, fn_init = 0, fn_end = math.pi / 2},
    COS = {fn = math.cos, fn_init = 0, fn_end = math.pi / 2},
    SQR = {fn = function(x) return x * x end, fn_init = 0, fn_end = 1},
    SQRT = {fn = function(x) return math.sqrt(x) end, fn_init = 0, fn_end = 1},
  },
  default = {},
  _pending = {},
  paused = {},
  _change_list = {},
  _purge_list = {},
  _fps = 60
}
anim.default.duration = 0.5
anim.default.fn = anim.fn.LINE

local function assert_required(params)
  for k, v in ipairs(params) do
    assert(v, string.format(
      'ANIM_ERROR: Property \'%s\' is required.', k)
    )
  end
end

local function is_range(t)
  return #t == 2 and type(t[1]) == 'number' and type(t[2]) == 'number'
end

-- replicate node's internal structure (minus the leaves)
local function replicate_structure(node, co_node)
  local k, v = next(node)
  while k do
    if type(v) == 'table' then
      co_node[k] = {}
      replicate_structure(v, co_node[k])
    else
      co_node[k] = v
    end
    k, v = next(node, k)
  end
end

local function replicate_structure_range(node, co_node)
  local k, v = next(node)
  while k do
    if type(v) == 'table' and not is_range(v) then
      co_node[k] = {}
      replicate_structure_range(v, co_node[k])
    elseif is_range(v) then
      co_node[k] = 'range'
    end
    k, v = next(node, k)
  end
end

local function traverse(node, fn) -- node and co_node have same structure
  local k, v = next(node)
  while k do
    if type(v) == 'table' then
      traverse(v, fn)
    else
      -- perform 'fn' on elements 'node', 'k', 'v'
      fn(node, k, v)
    end
    k, v = next(node, k)
  end
end

local function co_traverse(node, co_node, fn) -- node and co_node have same structure
  local k, v = next(node)
  local co_v = co_node[k]
  while k do
    if type(v) == 'table' then
      co_traverse(v, co_v, fn)
    else
      fn(node, co_node, k, v, co_v)
    end
    k, v = next(node, k)
    co_v = co_node[k]
  end
end

local function triple_traverse(node, co_node_1, co_node_2, fn) -- node and co_node have same structure
  local k, v = next(node)
  local co_v_1, co_v_2 = co_node_1[k], co_node_2[k]
  while k do
    if type(v) == 'table' then
      triple_traverse(v, co_v_1, co_v_2, fn)
    else
      fn(node, co_node_1, co_node_2, k, v, co_v_1, co_v_2)
    end
    k, v = next(node, k)
    co_v_1, co_v_2 = co_node_1[k], co_node_2[k]
  end
end

local function triple_traverse_range(node, co_node_1, co_node_2, fn) -- node and co_node have same structure
  local k, v = next(node)
  local co_v_1, co_v_2 = co_node_1[k], co_node_2[k]
  while k do
    if type(v) == 'table' and not is_range(v) then
      triple_traverse_range(v, co_v_1, co_v_2, fn)
    else
      fn(node, co_node_1, co_node_2, k, v, co_v_1, co_v_2)
    end
    k, v = next(node, k)
    co_v_1, co_v_2 = co_node_1[k], co_node_2[k]
  end
end

local function co_traverse_range(node, co_node, fn) -- node and co_node have same structure
  local k, v = next(node)
  local co_v = co_node[k]
  while k do
    if type(v) == 'table' and not is_range(v) then
      co_traverse_range(v, co_v, fn)
    else
      -- perform 'fn' on elements 'node', 'k', 'v'
      fn(node, co_node, k, v, co_v)
    end
    k, v = next(node, k)
    co_v = co_node[k]
  end
end

local function co_traverse_range_single(node, co_node, fn) -- node and co_node have same structure
  local k, v = next(node)
  local co_v = co_node[k]
  if type(v) == 'table' and not is_range(v) then
    co_traverse_range_single(v, co_v, fn)
  else
    -- perform 'fn' on elements 'node', 'k', 'v'
    fn(node, co_node, k, v, co_v)
  end
end

-- local function single_traverse(node, fn, _lineage)
--   if not _lineage then
--     _lineage = {}
--   end
--   local k, v = next(node)
--   if type(v) == 'table' then
--     _lineage[#_lineage+1] = k
--     single_traverse(v, fn, _lineage)
--   else
--     fn(node, k, v)
--   end

--   return _lineage
-- end

local function frame_eq(x, init, fin, last_frame)
  return lume.clamp(
    math.ceil(lume.lerp2(x, init, fin, 1, last_frame)), 1, last_frame
  )
end

local function frame_eq_free(x, init, fin, last_frame)
  return math.ceil(
    lume.lerp2(x, init, fin, 1, last_frame)
  )
end

local function calc_num_frames(fps, duration)
  return math.floor(fps * duration) + 1 -- + 1 for the case
  -- where math.floor(...) returns 0
end

local function construct_animation_frames(old, curr, num_frames, fn_bag) -- n is the number of frames

  local fn, input_init, input_end = 
    fn_bag.fn, fn_bag.fn_init, fn_bag.fn_end
  local output_init, output_end = 
    fn(input_init), fn(input_end)

  local delta = (input_end - input_init) / num_frames

  local frames = {}

  for i = 1, num_frames do
    frames[i] = lume.lerp2(
      fn(input_init + delta * i),
       output_init, output_end,
       old, curr
      ) -- mapping
  end

  return frames
end

function anim:move(params) -- {[id,] obj, props, [duration, fn]}

  params.obj = params[1] or params.obj
  params.id = params.id or params.obj
  params.props = params.props or params.to
  params.duration, params.fn = 
  params.duration or anim.default.duration, params.fn or anim.default.fn
  params.on_end =
  params.on_end or function() end -- nothing happens on default
  params.while_animating = params.while_animating or function() end
  
  assert_required({
    obj = params.obj,
    props = params.props
  })

  local bag = {
    obj = params.obj,
    on_end = params.on_end,
    props = params.props,
    while_animating = params.while_animating
  }

  -- add frames to bag
  bag.frames, bag.curr_frame, bag.last_frame =
    {}, 0, calc_num_frames(self._fps, params.duration)
    -- animation not started, curr_frame is 0

  co_traverse(
    params.props, params.obj,
    function(node, co_node, prop_name, prop_val, obj_prop_val)
      assert(
      obj_prop_val ~= nil,
      string.format(
        'ANIM_ERROR: Property \'%s\' not initialized!',
        prop_name
      ))

      if not bag.frames[co_node] then
        bag.frames[co_node] = {}
      end
      bag.frames[co_node][prop_name] = construct_animation_frames(
        obj_prop_val,
        prop_val,
        bag.last_frame,
        params.fn
      )
    end
  )

  
  self._pending[params.id] = bag
end

-- cool alternative ->

-- anim:move{rotation_box, to = {x = 4}}

function anim:attach(params) -- attach { object, to = other_object, where {input property with range} controls {output propert(ies) with ranges)}
  -- alternate calling:
  -- {id, input_obj, output_obj, input_prop, output_props}
  -- (attach { object, to = other_object,
  --  where {input property with range}
  -- controls {output propert(ies) with ranges)})
  params.input_obj = params[1] or params.input_obj
  params.output_obj = params.to or params.output_obj
  params.input_prop = params.where or params.input_prop
  params.output_props = params.controls or params.output_props

  assert_required({
    input_obj = params.input_obj,
    output_obj = params.output_obj,
    input_prop = params.input_prop,
    output_props = params.output_props,
  })

  params.id = params.id or params.output_obj
  params.while_animating = params.while_animating or function () end
  params.on_end = params.on_end or function() end
  params.clamp = (params.clamp == nil) or params.clamp

  params.duration, params.fn =
    params.smoothness or params.duration or anim.default.duration,
    params.fn or anim.default.fn
  
  local bag = {
    input_obj = params.input_obj,
    output_obj = params.output_obj,
    input_prop = params.input_prop,
    output_props = params.output_props,
    clamp = params.clamp,

    on_end = params.on_end,
    while_animating = params.while_animating,
    attached_anim = true
  }

  bag.frames, bag.prev_frame, bag.curr_frame, bag.last_frame = 
    {}, 0, 1, calc_num_frames(self._fps, params.duration)
  
  assert(
    next(params.input_prop) ~= nil,
    string.format('ANIM_ERROR: Field \'input_prop\' cannot be empty!')
  )

  co_traverse_range(
    params.output_props, params.output_obj,
    function(node, co_node, prop_name, prop_range, obj_prop_val)
      assert(
      obj_prop_val ~= nil,
      string.format(
        'ANIM_ERROR: Property \'%s\' not initialized!',
        prop_name
      ))

      if not bag.frames[co_node] then
        bag.frames[co_node] = {}
      end
      local frames = construct_animation_frames(
        prop_range[1],
        prop_range[2],
        bag.last_frame,
        params.fn
      )
      table.insert(frames, 1, prop_range[1])
      -- since the first frame is not contained
      -- within the generated frames
      bag.frames[co_node][prop_name] = frames
    end
  )

  bag.last_frame = bag.last_frame + 1
  -- since we added an additional frame (the vanilla initial one)
  self._pending[params.id] = bag
end

function anim:state_diff(state_1, state_2)
  local new_state = {}
  replicate_structure(state_1, new_state)
  triple_traverse(
    new_state, state_1, state_2,
    function(node, co_node_1, co_node_2, k, v, init, fin)
      node[k] = {init, fin}
    end
  )
  return new_state
end

function anim:state_diff_2(state_1, state_2)
  local new_state = {}
  replicate_structure(state_2, new_state)
  triple_traverse(
    new_state, state_1, state_2,
    function(node, co_node_1, co_node_2, k, v, init, fin)
      node[k] = {init, fin}
    end
  )
  return new_state
end

function anim:update(dt)
  -- self._fps = 1 / dt
  for id, bag in pairs(self._change_list) do
    if not self.paused[id] then
      -- MAIN PART
      if not bag.attached_anim then
        bag.curr_frame = bag.curr_frame + 1

        if bag.curr_frame <= bag.last_frame then
          co_traverse(
            bag.props, bag.obj,
            function(_, co_node, k)
              co_node[k] = bag.frames[co_node][k][bag.curr_frame]
            end
          )
          bag.while_animating(bag.obj)
        else
          -- perform on_end action
          self._change_list[id] = nil -- delete animation
            bag.on_end(bag.obj)
        end
      else -- attached_anim
        local input_obj, prop_range, prop_name
        co_traverse_range_single(
          bag.input_prop, bag.input_obj,
          function(node, co_node, k, v)
            input_obj, prop_range, prop_name = co_node, v, k
          end
        )
        bag.prev_frame = bag.curr_frame

        if bag.clamp then
          bag.curr_frame = frame_eq(
            input_obj[prop_name],
            prop_range[1],
            prop_range[2],
            bag.last_frame
          )
        else
          bag.curr_frame = frame_eq_free(
            input_obj[prop_name],
            prop_range[1],
            prop_range[2],
            bag.last_frame
          )
        end

        if bag.curr_frame ~= bag.prev_frame then
          if bag.curr_frame >= 1 and bag.curr_frame <= bag.last_frame then
            co_traverse_range(
              bag.output_props, bag.output_obj,
              function(_, co_node, k)
                co_node[k] = bag.frames[co_node][k][bag.curr_frame]
              end
            )
            bag.while_animating(bag.output_obj)
            if bag.curr_frame == bag.last_frame then
              bag.on_end(bag.output_obj)
            end
          end
        end
      end
      -- /MAIN PART
    end
  end
  for id, bag in pairs(self._pending) do
    self._change_list[id] = bag
    self._pending[id] = nil
  end

  for id in pairs(self._purge_list) do
    self._change_list[id] = nil
    self._purge_list[id] = nil
    self.paused[id] = nil
  end
end

function anim:play(id)
  self.paused[id] = false
end

function anim:pause(id)
  self.paused[id] = true
end

function anim:purge(id)
  if self._change_list[id] then
    self._purge_list[id] = true
  end
end

function anim:add_fn(name, fn, input_init, input_end)
  self.fn[name] = {
    fn = fn, 
    fn_init = input_init,
    fn_end = input_end
  }
end

return anim


-- ADDITIONAL COMMENTS

--[[
  1. (FIXED) THIS SHOULD BE CHANGED!! VERY INCONSISTENTLY PLACED!!
     Why is it that the 'on_end' handler is passed to 
     anim:move({...}), but 'while_animating' handler is an 
     object property?? Very bad!!

     Make anim:move be something like:
     anim:move({obj, to, [id, on_end, while_animating]}).

     We are anyway not updating this module in the 'UNO' 
     project. BUT THAT PROJECT HAS A MEMORY LEAK WHICH I
     FIXED HERE OH MY GOD. But if we change the functioning
     of the 'while_animating' handler, WE WILL BE REQUIRED
     TO FIX ALL INSTANCES OF IT IN CODE OH MY GOD. Ok no need
     to hyperventilate, how many instances could there possibly 
     be?

  2. while_animating was being called for EVERY. SINGLE. PROP. in our object.
     we dodged a serious bullet here, with this overhaul.

  3. 'seconds' has been renamed to 'duration'. sounds better when typing.
]]