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
    self.openchestentity = chestentity
    minetest.after(math.random(3), function()
      if self and self.object and self._tel_timer and self._tel_timer > 0 then
        chestentity:close("herobrine")
        self._tel_timer = 1
      end
    end)
  end
  
  local chestinv = core.get_inventory({type="node", pos=cpos})
  
  for i=1, math.random(50) do
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


herob.register_prank("tnt_trap", {
  type="base_indexed",
  requires={fullnode=true},
  has={"mcl_tnt:tnt", "pressure_plate"}
}, function(self)
  
  local npos = self.intent.prank_pos
  core.set_node(vector.add(npos, vector.new(0,1,0)), {name="mesecons_pressureplates:pressure_plate_sprucewood_off"})
  core.set_node(vector.add(npos, vector.new(0,-1,0)), {name="mcl_tnt:tnt"})
  self._tel_timer = 1
end)


herob.register_prank("fire", {nodenames = herob.flammable, under_air = true, distance_from_player=5, has={"mcl_fire:flint_and_steel"}}, function(self)
  
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

herob.register_prank("lava_on_base", {type="base_indexed", has={"mcl_buckets:bucket_lava"}}, function(self)
  
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



-- this needs to be in the api of the mob itself and not a addition
function herob.mine_substance(prankname, nodenames, def)
  def = def or {}
  local tooltypes = {
    "pickaxe",
    "shovel",
    "axe",
    "sword",
  }
  herob.register_prank(prankname, {
    nodenames = nodenames,
    distance_from_player = def.distance_from_player or 10,
    persistent = function(self, dtime, moveresult)
      local s = self.object:get_pos()
      
      
      if self._node_mining then
        self:set_velocity(0)
        self._locked_object = nil
        self:set_yaw(core.dir_to_yaw(vector.direction(s, self._node_mining.pos)))
        
        self:set_animation("punch")
        
        local node = self._node_mining.node
        self._node_mining.timer = self._node_mining.timer - dtime
        self._node_mining.soundtimer = self._node_mining.soundtimer - dtime
        
        if self._node_mining.timer < 0 then
          core.dig_node(self._node_mining.pos)
          minetest.sound_play(core.registered_nodes[node.name].sounds.dug, {pos=self._node_mining.pos, max_hear_distance=8}, true)
          self:set_animation("stand")
          self._node_mining = nil
        else
          if self._node_mining.soundtimer < 0 then
            self._node_mining.soundtimer = 0.34
            minetest.sound_play(core.registered_nodes[node.name].sounds.dig, {pos=self._node_mining.pos, max_hear_distance=8}, true)
          end
        end
      end
      
      
      
      if self._node_mining then return end
      
      if not self.minelist then
        -- create list of positions to mine (like for a tree etc)
        local nodepositions, amounts = core.find_nodes_in_area(vector.subtract(s, 10), vector.add(s, 10), herob.pranks[self.intent.current_prank].nodenames)
        self.minelist = nodepositions
      elseif #self.minelist and #self.minelist > 0 then
        local minenode = self.minelist[#self.minelist]
        local gopath = herob.find_spawn_near(minenode, self.reach, true)
        local can_reach_block = vector.distance(vector.add(s, vector.new(0,1.4,0)), minenode) < self.reach
        if not can_reach_block and self:ready_to_path() and not self.nopath and gopath then
          local path = self:gopath(gopath,herob.get_prank_function(self, herob.pranks[self.intent.current_prank].func))
          if not path then
            self.nopath = true
          end
        elseif not can_reach_block and self.notpath then
          if s.y > minenode.y then
            --print("Cant reach it! mining down")
            self.minelist[#self.minelist+1] = vector.add(s, vector.new(0,-1,0))
          else
            --table.insert(self.minelist, )
            --print("Cant reach it! horrizontally")
          end
        elseif can_reach_block then
          herob.get_prank_function(self, herob.pranks[self.intent.current_prank].func)(self)
        end
      elseif self._tel_timer > 1 then
        self._tel_timer = 1
      end
      
    end,
  }, function(self)
    if not self.minelist or self.minelist and not self.minelist[1] then return end
    
    local node = core.get_node(self.minelist[#self.minelist])
    local tool_def = {}
    local using_hand
    for _,ttype in pairs(tooltypes) do
      local def = core.registered_nodes[node.name]
      local ttypey = ttype.."y"
      if def.groups[ttypey] then
        
        local tool, tool_id = herob.get_item_from_inv(herob.get_inv(), nil, nil, ttype)
        if tool and tool:get_name() then
          tool_def = core.registered_items[tool:get_name()].groups
          self.set_wielded_item(self, tool_id)
          --print("I have a tool for this!")
        else
          using_hand = true
          --print("I don't have a good tool for this..")
        end
      end
    end
    
    local tool_speed = (tool_def.dig_speed_class or 0)+1
    local tool_speed = tool_speed*tool_speed
    
    -- Let me explain..
    -- hardness is a weird thingy, obsidian is 50, snow is 0.1
    -- So this is some math that makes hb mine at similar speeds to what
    -- the player would using the same tools. :shrug. Idk what the actual math is.
    local timetomine =
    (core.registered_nodes[node.name]._mcl_hardness or 1)*(
      4*(
        core.registered_nodes[node.name]._mcl_hardness/40+1
      )
    )/tool_speed
    
    if using_hand then timetomine = timetomine/2 end
    
    self._node_mining = {
      node = node,
      pos = self.minelist[#self.minelist],
      timer = timetomine,
      soundtimer = 0,
    }
    
    --print("Mining this block with the tools I have is going to take roughly "..timetomine.." seconds..")
    
    self.minelist[#self.minelist] = nil
  end)
end




herob.mine_substance("mine_wood", {
  "mcl_core:tree",
  "mcl_core:darktree",
  "mcl_core:acaciatree",
  "mcl_core:sprucetree",
  "mcl_core:birchtree",
  "mcl_core:jungletree",
})


herob.mine_substance("mine_chest", {
  "mcl_chests:chest_small",
  "mcl_chests:chest_left",
  "mcl_chests:chest_right",
  "mcl_chests:trapped_chest_small",
  "mcl_chests:trapped_chest_left",
  "mcl_chests:trapped_chest_right",
})
