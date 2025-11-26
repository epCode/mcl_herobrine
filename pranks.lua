herob.register_prank("loot_chest", {nodenames = herob.lootablechests, creep_line_chance = 5, creep_lines={"You have some goodies here..", "Glad you left your chests unlocked.."}}, function(self)
  
  local cpos = self.intent.at_target
  
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

herob.register_prank("tnt_trap", {nodenames = herob.manmade, under_air = true}, function(self)
  
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
  
  
  core.dig_node(npos, self.object)
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
  
  
  core.dig_node(npos, self.object)
  minetest.sound_play("default_dig_choppy", {pos=npos, max_hear_distance=8}, true)
  self._tel_timer = 1
end)