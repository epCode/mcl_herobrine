-- Note to self:
-- For each prank, add a disable feature in settingtypes.txt
-- I wish there was a more modular way to do this :P


-- returning true for a prank indicates faliure.

herob.register_prank("loot_chest", {nodenames = herob.lootablechests, creep_line_chance = 5, creep_lines={"You have some goodies here..", "Glad you left your chests unlocked.."}}, function(self)
  
  local cpos = self.intent.prank_pos
  if not cpos then return true end
  
  local node = minetest.get_node(cpos)
  
  local objs = core.get_objects_inside_radius(cpos, 2)
  local chestentity
  for _,obj in pairs(objs) do
    if obj:get_luaentity() and string.find(obj:get_luaentity().name, "chest") then
      chestentity = obj:get_luaentity()
      break
    end
  end
  if chestentity then
    chestentity:open("herobrine")
    minetest.after(math.random(5), function()
      chestentity:close("herobrine")
      self._tel_timer = 1
    end)
  end
  
  local chestinv = core.get_inventory({type="node", pos=cpos})
  
  for i=1, math.random(36) do
    local stack, id = herob.get_item_from_inv(chestinv, herob.priority_takes[math.random(#herob.priority_takes)])
    if stack then
      herob.add_to_inv(stack)
      stack:clear()
      chestinv:set_stack("main", id, stack)
    else
      self._tel_timer = 1
    end
  end
end)


herob.register_prank("tnt_trap", {type="base_indexed", requires={fullnode=true}}, function(self)
  
  local npos = self.intent.prank_pos
  core.set_node(vector.add(npos, vector.new(0,1,0)), {name="mesecons_pressureplates:pressure_plate_sprucewood_off"})
  core.set_node(vector.add(npos, vector.new(0,-1,0)), {name="mcl_tnt:tnt"})
  self._tel_timer = 1
end)


herob.register_prank("fire", {nodenames = herob.flammable, under_air = true, distance_from_player=5}, function(self)
  
  local npos = self.intent.prank_pos
  local pointed_thing = {under = npos, above = vector.add(npos, vector.new(0,1,0)), type = "node"}
  
  local nodedef = minetest.registered_nodes[core.get_node(npos).name]
  if nodedef and nodedef._on_ignite then
    local overwrite = nodedef._on_ignite(self.object, pointed_thing)
    if not overwrite then
      used = mcl_fire.set_fire(pointed_thing, self.object, false)
    end
  else
    used = mcl_fire.set_fire(pointed_thing, self.object, false)
  end
  minetest.sound_play("fire_flint_and_steel", {pos=npos, max_hear_distance=8}, true)
  self._tel_timer = 1
end)

herob.register_prank("take_torch", {nodenames = herob.torches, distance_from_player=8}, function(self)
  
  local npos = self.intent.prank_pos
  
  
  core.dig_node(npos)
  minetest.sound_play("default_dig_choppy", {pos=npos, max_hear_distance=8}, true)
  self._tel_timer = 1
end)

herob.register_prank("take_bed", {
  nodenames = herob.beds,
  distance_from_player=8,
  creep_line_chance = 5,
  creep_lines={
    "Sleep tight tonight..",
    "I hope you rest well..",
    "Whoops.."
  }
}, function(self)
  
  local npos = self.intent.prank_pos
  
  
  core.dig_node(npos)
  minetest.sound_play("default_dig_choppy", {pos=npos, max_hear_distance=8}, true)
  self._tel_timer = 1
end)

--[[ -- Super evil. Don't use, just for testing.
herob.register_prank("change_base_to_stone", {
  type="base_indexed",
  distance_from_player=30,
}, function(self)
  
  for i,position in pairs(self.intent.current_base) do
    print(i)
    core.set_node(position, {name="mcl_core:stone"})
  end
  
  minetest.sound_play("default_dig_choppy", {pos=npos, max_hear_distance=8}, true)
  self._tel_timer = 1
end)]]

herob.register_prank("lava_on_base", {type="base_indexed"}, function(self)
  
  local npos = self.intent.prank_pos
  core.place_node(vector.add(npos, vector.new(0,1,0)), {name="mcl_core:lava_source"})

  self._tel_timer = 1
end)

herob.register_prank("push_player_off_cliff", {type="player_indexed",
  get_custom_spawn = function(player)
    local p = player:get_pos()
    
    local possible_cliff_tops = {
      vector.new(0,0,-1),
      vector.new(0,0,1),
      vector.new(-1,0,0),
      vector.new(1,0,0)
    }
    local spawn_offsets = {
      vector.new(0,1,0),
      vector.new(0,-1,0),
      vector.new(0,0,0),
    }
    
    for _i,spoff in pairs(spawn_offsets) do -- one block varience allowed
      for i,offset in pairs(possible_cliff_tops) do
        local offsetpos = vector.add(p, offset)
        local spawnpos = vector.add(vector.add(p, vector.multiply(offset, -1)), spoff)
        local spawnpos_above = vector.add(spawnpos, vector.new(0,1,0))
        local spawnpos_below = vector.add(spawnpos, vector.new(0,-1,0))
          
        if herob.walknode(spawnpos_below) and not herob.walknode(spawnpos_above) and herob.spawn_is_ok(spawnpos) then
          -- if ground and no head obstuction and player cannot see us and light levels are ok etc.
          local ray = core.raycast(offsetpos, vector.add(offsetpos, vector.new(0,-5,0)), false, false)
          local works = true
          for pointed_thing in ray do
            if herob.walknode(pointed_thing.under) then
              works = false
            end
          end
          if works then
            return {prank_pos=spawnpos, direct_spawn=true}
          end
        end      
      end
    end
  end
  },
  function(self)
    
    local player = core.get_player_by_name(self.intent._pranked_player_name)
    if not player then self._tel_timer = 1; return end
    
    self:mob_sound("attack")
    player:punch(self.object, 1.0, {
      full_punch_interval = 1.0,
      damage_groups = {fleshy = 1}
    }, nil)
    
    player:add_velocity(vector.multiply(vector.add(vector.direction(self.object:get_pos(), player:get_pos()), vector.new(0,0.7,0)), 7))

    self._tel_timer = 1
  end
)