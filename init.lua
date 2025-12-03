herob = {
  pranks = {},
  wieldview_luaentites = {}
}

local AVERAGESPAWN = tonumber(core.settings:get("average_spawn_time")) or 900
core.log("action", "Average time between herobrine spawn set to "..AVERAGESPAWN.." seconds, or "..(AVERAGESPAWN/60).." minutes.")

local ONEATATIME = core.settings:get_bool("one_at_a_time")
herob.all_bases = {} -- needs to be a playername indexed list of base clusters
local BASE_EPSILON = 60    -- max distance between points in the same base (60 blocks radius)
local MIN_BASE_BLOCKS = 200 -- minimum number of blocks to be considered a significant 'base'



local modname = core.get_modpath("mcl_herobrine")
dofile(modname.."/defines.lua")



-- if herobrine already exists substantially somewhere else,
-- than do not allow more than one of him to spawn
herob.herobrine_is = false

-- Neferious deeds TODO:
-- Watch them
-- Make creeper sound
-- Mine trees
-- Strip (mine)
-- 


-- Herobrine's collisionbox
local hb_collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.89, 0.3}
local DST -- Disables view teleportation for debug and testing


local function herobrine_exists()
  if ONEATATIME == false then
    return false
  else
    return herob.herobrine_is
  end
end



function herob.register_prank(name, def, func)
  local setting = core.settings:get_bool("enable_prank_"..name)
  -- if this prank is disabled then do not register it. (it may return nil which
  -- just means it hasn't been set yet) so defaulting to true
  if setting == false then core.log("action", "Prank: "..name.." is disabled") return end
  def.type = def.type or "node_indexed" -- types:
  -- player_indexed : player position.
  -- node_indexed   : certain nodes around player.
  -- base_indexed   : Spawn in the player's base.
  
  def.persistent = def.persistent or function(self, dtime, moveresult) return true end
  -- global step (if return = false then normal prank code is not run for this prank.)
  -- eg; pathfinding to prank_pos.. That's basically it. If returned true, globalstep continues as normal
  def.requires = def.requires or {}
  def.creep_line_chance = def.creep_line_chance or 1 -- how often Herobrine will send to player chat a creep line after a Neferious deed.
  def.distance_from_player = def.distance_from_player or 30 -- how far around the player to look
  def.func = func -- what to do when we get to where we're going.
  herob.pranks[name] = def
end




function herob.get_inv()
  local invpos = vector.new(0, -1, 0) -- absalute worst way to do this. Don't do this.
  local heroinv = core.get_inventory({type="node", pos=invpos})
  
  if not heroinv or heroinv and not heroinv:get_list("main") then
    local meta = core.get_meta(invpos)
    
    heroinv = meta:get_inventory()
  end
  heroinv:set_size("main", 9 * 4)
  
  return heroinv
end

function herob.add_to_inv(stack)
  local heroinv = herob.get_inv()
  
  return heroinv:add_item("main", stack)
end
dofile(modname.."/base_finder.lua")

-- this function makes eight raycasts (one for each point of a collisionbox) and decides whether
-- pos1 (player's eye pos) can see any of those points. Making for a more reliable los.
local function los(pos1, pos2, col) -- better, more case specific line of sight algo
  local eight_points = { -- all eight points of the collisionbox for an accurate: `can I see you?`
    vector.new(col[1], col[2], col[3]),
    vector.new(col[1], col[5], col[6]),
    vector.new(col[1], col[2], col[6]),
    vector.new(col[1], col[5], col[3]),
    
    vector.new(col[4], col[5], col[6]),
    vector.new(col[4], col[2], col[3]),
    vector.new(col[4], col[2], col[6]),
    vector.new(col[4], col[5], col[3]),
  }
  
  local cansee = false
  
  for _,point in pairs(eight_points) do
    local node = false
    local ray = core.raycast(pos1, vector.add(pos2, point), true, false)
    for pthing in ray do
      if pthing.type == "node" then
        if core.registered_nodes[core.get_node(pthing.under).name].walkable then
          node = true
          break
        end
      end
    end
    if not node then cansee = true; break end
  end
  
  return cansee
end

local telesound = function(pos)
	local snd = "mcl_herobrine_teleport"
	core.sound_play(snd, {pos=pos, max_hear_distance=16, gain=10}, true)
end

local check_players = function(s, leway, collisionbox)
  -- can player see us from this position (based on player screen and los)
  -- leway is how far behind the player we must allow.
  -- eg. 1 = 90 degrees (Can spawn to the left, right, or anywhere behind)
  -- 0.5 = visible on edges of screen
  -- 2 = ~135 degrees (Can spawn mostly just behind player.)  etc.
  leway = leway or 1
  for _,player in pairs(core.get_connected_players()) do
    local p, dir = player:get_pos(), player:get_look_dir()
    
    local dist = vector.distance(p, s)
    local lookpos = vector.add(vector.multiply(dir, dist), p)
    
    -- vector.distance(lookpos, s) < (dist*leway)/math.ceil(dist/25)
    -- This bit of code ^^
    -- essentially defines the players fov (not utilizing fov itself)
    -- and makes it directly preportionate to player distance and projected
    -- eye position distance. the farther away however, the more hero can
    -- be on your screen "blindspots essentially" since he's too far away.
    
    -- when he's 25 or more blocks, away the amount he can be on your screen increases.
    
    if vector.distance(lookpos, s) < (dist*leway)/math.ceil(dist/25) and los(vector.add(p, vector.new(0,player:get_properties().eye_height,0)), s, collisionbox) then
      if DST then
        return
      else
        return true
      end
    end
  end
end


function herob.spawn_is_ok(pos, light_insensitive)
  local twopos = core.get_node(vector.add(pos, vector.new(0,1,0)))
  if not core.registered_nodes[twopos.name].walkable -- must have headspace to spawn in
  and not check_players(pos, 1.5, hb_collisionbox) -- players cannot see us spawn
  and (core.get_node_light(vector.add(pos, vector.new(0,2,0))) < 3 or light_insensitive) then -- cannot spawn in light above 4 (Can walk in it tho)
    return true
  end
end

-- returns the most favorable spawn trying to reach `pos` from within `rad` distance
function herob.find_spawn_near(pos, rad, light_insensitive)
  if not pos then return end
  local poss = core.find_nodes_in_area_under_air(vector.subtract(pos, rad), vector.add(pos, rad), {"mcl_core:dirt_with_grass", "group:stone", "group:wood", "group:sand", "group:handy", "group:pickaxey", "group:shovely", "group:axey", "group:swordy"})
  
  -- go through all availble positions and score based on distance to target and
  -- disallow if the player can see us, or the light level is higher than 2
  if #poss then
    
    local highest_score = {-1, poss[1]}
    
    for i,telepos in pairs(poss) do
      local tpos = vector.add(telepos, vector.new(0,1,0))
      local dist = vector.distance(tpos, pos)
      if (dist < highest_score[1] or highest_score[1] == -1) -- must be closer to target than out last valid pos
      and herob.spawn_is_ok(tpos, light_insensitive) then -- cannot spawn in light above 4 (Can walk in it tho)
        highest_score = {dist, tpos}
      end
    end
    if highest_score[1] ~= -1 then
      return highest_score[2]
    end
  end
end


local function spawn(pos, intent)
  -- disabled log because it happens to often
  if not pos then --[[core.log("warning", "Tried to spawn herobrine but no valid position found!")]] return end
  local obj = core.add_entity(pos, "mcl_herobrine:herobrine")
  herob.herobrine_is = true
  local lua = obj:get_luaentity()
  
  lua.intent = intent
  
  core.log("action", "Herobrine spawned at "..core.pos_to_string(pos).." with intent to commit prank "..intent.current_prank..".")
  
  --herob.herobrine_is = true
end


-- find item in inventory based on a the presense of property, group, or if their name contains `findstring`
function herob.get_item_from_inv(cinv, findstring, property, group)
	local item_stack, item_stack_id
  if not cinv then return end
	for i=1, cinv:get_size("main") do
		local it = cinv:get_stack("main", i)
    if findstring then
  		if not it:is_empty() and string.find(it:get_name(), findstring) then
  			item_stack = it
  			item_stack_id = i
  			break
  		end
    elseif property then
      if not it:is_empty() and core.registered_items[it:get_name()][property] then
  			item_stack = it
  			item_stack_id = i
  			break
  		end
    elseif group then
      local gr = core.registered_items[it:get_name()].groups[group]
      if not it:is_empty() and gr and gr > 0 then
  			item_stack = it
  			item_stack_id = i
  			break
  		end
    end
	end
	return item_stack, item_stack_id
end


-- Yoinked from MCL code, but tailored to HB
local function update_wieldview_entity(object)
	local luaentity = herob.wieldview_luaentites[object]
  local item = object:get_luaentity().wielded_item:get_name()
	if luaentity and luaentity.object:get_yaw() then


		if item == luaentity._item then return end

		luaentity._item = item

		local def = object:get_luaentity().wielded_item:get_definition()
		if def and def._mcl_wieldview_item then
			item = def._mcl_wieldview_item
		end

		local item_def = core.registered_items[item]
		luaentity.object:set_properties({
			glow = item_def and item_def.light_source or 0,
			wield_item = item,
			is_visible = item ~= ""
		})
    
    
	else
		-- If the player is running through an unloaded area,
		-- the wieldview entity will sometimes get unloaded.
		-- This code path is also used to initalize the wieldview.
		-- Creating entites from core.register_on_joinplayer
		-- is unreliable as of Luanti 5.6
		local obj_ref = core.add_entity(object:get_pos(), "mcl_wieldview:wieldview")
		if not obj_ref then return end
    if core.registered_tools[item] then
      obj_ref:set_attach(object, "Wield_Item", vector.new(0,2.2,0), vector.new(90+180,45-90,90))
    else
      obj_ref:set_attach(object, "Wield_Item")
    end
		--obj_ref:set_attach(player, "Hand_Right", vector.new(0, 1, 0), vector.new(90, 45, 90))
		herob.wieldview_luaentites[object] = obj_ref:get_luaentity()
	end
end

-- Is the node at `pos` walkable?
function herob.walknode(pos, fullnode)
  local node = core.get_node(pos)
  local walkable
  if node then
    local def = core.registered_nodes[node.name]
    walkable = def.walkable
    if fullnode then
      walkable = walkable and def.buildable_to and not def.node_box
    end
  end
  return walkable
end

local numtohex = {
  [0] = "0",
  [1] = "1",
  [2] = "2",
  [3] = "3",
  [4] = "4",
  [5] = "5",
  [6] = "6",
  [7] = "7",
  [8] = "8",
  [9] = "9",
  [10] = "a",
  [11] = "b",
  [12] = "c",
  [13] = "d",
  [14] = "e",
  [15] = "f",
}

function herob.get_prank_function(self, prankfunc)
  -- stuff to run before running defined prank func
  local prank = herob.pranks[self.intent.current_prank]
  local function func(self, pos)

    self.intent.at_target = self.intent.prank_pos -- (we have arrived, stop trying to reach)
    if not prankfunc(self, pos) then
      if math.random(prank.creep_line_chance) == 1 and prank.creep_lines then
        local cl = prank.creep_lines[math.random(#prank.creep_lines)]
        
        local cla = {}
        for i = 1, #cl do
          local c = cl:sub(i,i)
          local brightness = numtohex[math.random(7,15)]
          c = core.colorize("#"..brightness..brightness..brightness, c)
          
          cla[i] = c
        end
        
        cl = table.concat(cla, '')
        
        core.chat_send_all(cl)
      end
    end
  end
  return func
end

local herobrine = {
	description = "Herobrine",
	type = "npc",
	spawn_class = "passive",
	initial_properties = {
		hp_min = 20,
		hp_max = 20,
		breath_max = -1,
		collisionbox = hb_collisionbox,
	},
	xp_min = 5,
	xp_max = 5,
	head_swivel = "Head_Control",
	head_eye_height = 1.4,
	head_bone_position = vector.new( 0, 6.3, 0 ), -- for luanti <= 5.8
	curiosity = 7,
	head_pitch_multiplier=-1,
	wears_armor = 2,
	armor = {fleshy = 40},
	visual = "mesh",
	mesh = "mcl_armor_character.b3d",
	textures = {
		{
      "character.png", -- texture
			"mobs_mc_empty.png", -- armor
		}
	},
	makes_footstep_sound = true,
	sounds = {
		teleport = "mcl_herobrine_teleport",
		punch = "default_punch",
		distance = 8,
	},
  can_despawn = false,
	walk_velocity = 2,
	run_velocity = 2,
	damage = 7,
	reach = 3,
	pathfinding = 1,
	jump = true,
	jump_height = 4,
	group_attack = { "mcl_hb:herobrine", "mcl_hb:baby_herobrine", "mcl_hb:husk", "mcl_hb:baby_husk" },
	animation = {
		stand_start = 0, stand_end = 79, stand_speed = 1,
		walk_start = 168, walk_end = 187, speed_normal = 1,
		run_start = 168, run_end = 187, speed_run = 1,
		punch_start = 189, punch_end = 198, punch_speed = 2,
	},
	floats = 1,
	view_range = 128,
	attack_type = "dogfight",
  on_spawn = function(self)
    self.item_drop_management = function()
      
      local items_to_pickup = {}
      local s = self.object:get_pos()
      local objs = core.get_objects_inside_radius(s, 2.1)
      
      for _,obj in pairs(objs) do
        local le = obj:get_luaentity()
        if le and le.itemstring then
          table.insert(items_to_pickup, obj)
        end
      end
      
      for _,item in pairs(items_to_pickup) do
        local itemstring = item:get_luaentity().itemstring
        herob.add_to_inv(ItemStack(itemstring))
        minetest.sound_play("item_drop_pickup", { -- direct copy of sound code from `mcl_item_entity`
					pos = pos,
					gain = 0.3,
					max_hear_distance = 16,
					pitch = math.random(70, 110) / 100
				})
        item:remove()
      end
      
    end
    -- defining functions in a poor way
    self.set_wielded_item = function(self, stack_id)
      local inv = herob.get_inv()
      self.wielded_item_id = stack_id
      self.wielded_item = inv:get_stack("main", stack_id)
      -- dont question it..
      update_wieldview_entity(self.object)
      update_wieldview_entity(self.object)
    end
    -- if no position specified then teleport into the void
    -- else, go to position.
    self.teleportaway = function(self, position)
      local p = self.object:get_pos()
      local v = self.object:get_velocity()
      local nv = vector.multiply(v, -1)
      core.add_particlespawner({
      	amount = 5,
      	minpos = vector.add(vector.new(-0.25,0,-0.25), p),
      	maxpos = vector.add(vector.new(0.25,2,0.25), p),
      	minvel = vector.add(vector.new(-0.1,-0.1,-0.1), v),
      	maxvel = vector.add(vector.new(0.1,0.1,0.1), v),
      	minacc = vector.add(vector.new(-0.1,-0.1,-0.1), nv),
      	maxacc = vector.add(vector.new(0.1,0.1,0.1), nv),
      	minexptime = 0.2,
      	maxexptime = 1.5,
      	minsize = 1.2,
      	maxsize = 3.2,
      	collisiondetection = true,
      	vertical = false,
      	time = 0.001,
      	texture = {
          name = "mcl_portals_particle"..math.random(1, 5)..".png",
          alpha = 0.01,
          scale_tween = {
            {x = 1, y = 1},
            {x = 0, y = 0},
          },
          blend="screen",
        },
        glow=12,
      })
      telesound(p, true)
      --save_self(self)
      if self.openchestentity then
        self.openchestentity:close("herobrine")
      end

      if position then
        self.object:set_pos(position)
      else
        for _,child in pairs(self.object:get_children()) do
          child:remove()
        end
        self.object:remove()
        herob.herobrine_is = false
        return true
      end
    end
    
  end,
  do_punch = function(self, hitter, tflp, tool_capabilities, dir)
    self._tel_timer = -1 --teleport on the next tick
  end,
  use_texture_alpha=true,
  on_die = function(self)
    --local obj = core.add_entity(self.object:get_pos(), "mcl_herobrine:herobrine_dead")
    --obj:set_rotation(self.object:get_rotation())
    
    -- don't do normal death stuff when dead, vanish.
    self.object:set_properties({
      textures = {
        "character.png^[opacity:"..0, -- texture
        "mobs_mc_empty.png", -- armor
      },
    })
    
    -- drop stuff
    local heroinv = herob.get_inv()
    if heroinv then
      for i, stack in pairs(heroinv:get_list("main")) do
        if stack and stack ~= "" then
          local obj = core.add_item(self.object:get_pos(), stack)
          if obj then
            obj:add_velocity(vector.random_direction())
            stack:clear()
            heroinv:set_stack("main", i, stack)
          end
        end
      end
    end
    
    -- delete eyes
    for _,child in pairs(self.object:get_children()) do
      child:remove()
    end
    
    -- allow respawn
    herob.herobrine_is = false
  end,
  after_activate = function(self)
    -- add eyes whens spawn
    herob.herobrine_is = true
    core.add_entity (self.object:get_pos(), "mcl_herobrine:hero_eyes")
		:set_attach(self.object, "Head", vector.new(0,-14,-0.1), vector.new(0,180,0))
  end,
  do_custom = function(self, dtime, moveresult)
    self._ticktimer = (self._ticktimer or 0) + dtime
    
    
    local s = self.object:get_pos()
    
    if not self.intent or self.intent and not self.intent.current_prank then self._tel_timer = -1 end
    
    self.intent = self.intent or {}
    
    -- after teltimer is less than 0 and we are not attacking someone, teleport away
    self._tel_timer = (self._tel_timer or 40)-dtime
    if (self._tel_timer < 0 and not self.attack) or check_players(self.object:get_pos(), 1, hb_collisionbox) --[[or core.get_node_light(vector.add(s, vector.new(0,1,0))) >= 5]] then
      self.teleportaway(self)
      return false
    end
    
    
    if self.attack then --attack logic
      if math.random(100) == 1 then
        -- teleport to player instead of running
        local telepos = herob.find_spawn_near(self.attack:get_pos(), 3, true)
        if telepos then
          if self.teleportaway(self, telepos) then return false end
        end
      end
    end
    
    
    
    
    -- if we have a prank to carry out
    if self.intent.prank_pos and herob.pranks[self.intent.current_prank] and herob.pranks[self.intent.current_prank].persistent(self, dtime, moveresult) then
      local nearpos = herob.find_spawn_near(self.intent.prank_pos, 3, true)
      if self.intent.direct_spawn then nearpos = self.intent.prank_pos end
      if vector.distance(s, self.intent.prank_pos) < 1.5 and not self.intent.at_target then
        herob.get_prank_function(self, herob.pranks[self.intent.current_prank].func)(self)
      elseif nearpos and self:ready_to_path() and not self.intent.at_target and not self._necessary_path and herob.pranks[self.intent.current_prank] then
        local path = self:gopath(nearpos,herob.get_prank_function(self, herob.pranks[self.intent.current_prank].func))
        
        if not path and vector.distance(s, nearpos) > 1.5 then
          if self.teleportaway(self, nearpos) then return false end
          self.object:set_velocity(vector.zero())
          herob.pranks[self.intent.current_prank].func(self)
        else
          self._partial_path = false
        end
      elseif not nearpos then -- if we can't stand near our target then just leave.
        self.teleportaway(self)
        return false
      end
    end
    
    if self._ticktimer < 0.5 then return end -- everything past is every half second
    self._ticktimer = 0
    
    
    self.item_drop_management()


    
  end
}

mcl_mobs.register_mob("mcl_herobrine:herobrine", herobrine)


core.register_entity ("mcl_herobrine:hero_eyes", {
	initial_properties = {
		visual = "mesh",
		mesh = "mcl_armor_character.b3d",
		glow = 10,
		textures = {
			"mcl_hb_eyes.png",
			"mobs_mc_empty.png",
			"mobs_mc_empty.png",
			"mobs_mc_empty.png",
		},
		selectionbox = {
			0, 0, 0, 0, 0, 0,
		},
	},
	on_step = function(self)
		if self and self.object then
			if not self.object:get_attach() then
				self.object:remove()
			end
		end
	end,
})

--[[ -- unused
core.register_entity("mcl_herobrine:herobrine_dead", {
  visual = "mesh",
  mesh = "mcl_armor_character.b3d",
  textures = {
    "character.png", -- texture
    "mobs_mc_empty.png", -- armor
  },
  use_texture_alpha = true,
  on_activate = function(self)
    self.object:set_velocity(vector.new(0,10,0))
  end,
  on_step = function(self)
    self.object:set_velocity(vector.multiply(self.object:get_velocity(), 0.95))
    self._alpha = (self._alpha or 255) - 0.7
    if self._alpha < 0 then self.object:remove(); return end
    self.object:set_properties({
      textures = {
        "character.png^[opacity:"..self._alpha, -- texture
        "mobs_mc_empty.png", -- armor
      },
    })
  end,
})]]




-- Dev spawn egg (not for general use)
mcl_mobs.register_egg("mcl_herobrine:herobrine", "Herobrine", "#00afaf", "#799c66", 0)



local timer = math.random(AVERAGESPAWN*2) -- when timer hits zero, hero tries to spawn somewhere.
-- Herobrine player-tick
core.register_globalstep(function(dtime)
  if herobrine_exists() then return end
  timer = timer - dtime
  if timer < 0 then
    timer = math.random(AVERAGESPAWN*2)
    herob.update_player_bases()
    for _,player in pairs(core.get_connected_players()) do

      local pname = player:get_player_name()
      local pos = player:get_pos()


      --chests
      local possible_pranks = {}
      
      local i = 1
      
      -- run through each prank and find out if there are any applicable places to do these.
      for name,prank in pairs(herob.pranks) do
        if prank.has then -- `has` are tools required to pull this prank off.
          for _,item in pairs(prank.has) do
            local stack, id = herob.get_item_from_inv(herob.get_inv(), item)
            if not stack then
              goto continue
            end
          end
        end
        
        
        
        if prank.type == "node_indexed" then
          local prerecs, spawn
          local nodepostable, amounts
          if prank.get_custom_spawn then
            prerecs = prank.get_custom_spawn(player)
            if prerecs then
              spawn = prerecs.prank_pos
            end
          else
            if prank.under_air then
              nodepostable, amounts = core.find_nodes_in_area_under_air(vector.subtract(pos, prank.distance_from_player), vector.add(pos, prank.distance_from_player), prank.nodenames)
            else
              nodepostable, amounts = core.find_nodes_in_area(vector.subtract(pos, prank.distance_from_player), vector.add(pos, prank.distance_from_player), prank.nodenames)
            end
          end

          if not spawn then
            for i=1, 10 do
              spawn = nodepostable[math.random(#nodepostable)]
              if spawn and (prank.requires.fullnode and herob.walknode(spawn, true) or not prank.requires.fullnode) then
                --print(herob.walknode(spawn, true))
                break
              end
            end
          end
          
          if spawn then
            possible_pranks[i] = {
              current_prank=name,
              prank_pos=spawn,
              distance_from_player=prank.distance_from_player
            }
            i = i + 1
          end
          

        elseif prank.type == "player_indexed" then
          local prerecs, spawn
          if prank.get_custom_spawn then
            prerecs = prank.get_custom_spawn(player)
            if prerecs then
              spawn = prerecs.prank_pos
            end
          else
            spawn = herob.find_spawn_near(pos, prank.distance_from_player)
          end
            
          if spawn then
            possible_pranks[i] = {
              direct_spawn = prerecs.direct_spawn,
              current_prank=name,
              prank_pos=spawn,
              distance_from_player=prank.distance_from_player,
            }
          end
        elseif prank.type == "base_indexed" and herob.all_bases[pname] then
          local used_base, current_base
          for i,base_cluster in pairs(herob.all_bases[pname]) do
            local basepos = herob.get_mean_cluster_center(base_cluster)
            --print("There is a base we might use! "..vector.distance(pos, basepos).." nodes away from player")
            if vector.distance(pos, basepos) < BASE_EPSILON then
              used_base = basepos
              current_base = i
              break
            end
          end
          
          local nodepos = herob.find_spawn_near(used_base, BASE_EPSILON)
          if nodepos then
            possible_pranks[i] = {current_prank=name, prank_pos=vector.add(nodepos, vector.new(0,-1,0)), distance_from_player=prank.distance_from_player, current_base=herob.all_bases[pname][current_base]}
            i = i + 1
          end
        end
        ::continue::
      end
      
      if possible_pranks[1] then
        local prank_index = math.random(#possible_pranks)
        possible_pranks[prank_index]._pranked_player_name = player:get_player_name()
        local spawnpos = herob.find_spawn_near(possible_pranks[prank_index].prank_pos, possible_pranks[prank_index].distance_from_player)
        if possible_pranks[prank_index].direct_spawn then
          spawnpos = possible_pranks[prank_index].prank_pos
        end
        spawn(spawnpos, possible_pranks[prank_index])
        if herobrine_exists() then return end
      end


    end
  end
end)




-- add placed node to player base
core.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
  if not placer then return end
  
  --if math.random(2) == 1 then return end
  
  local meta = placer:get_meta()
  
  local placed_nodes = core.deserialize(meta:get_string("placed_nodes")) or {}
  placed_nodes[pos] = true
  
  meta:set_string("placed_nodes", core.serialize(placed_nodes))
  
  --print("placedanode")
end)

-- remove dug nodes from player base (Makes underground bases safer..)
core.register_on_dignode(function(pos, oldnode, digger)
  if not digger or digger and not digger:is_player() then return end
  
  --if math.random(2) == 1 then return end
  
  local meta = digger:get_meta()
  
  local placed_nodes = core.deserialize(meta:get_string("placed_nodes")) or {}
  placed_nodes[pos] = nil
  
  meta:set_string("placed_nodes", core.serialize(placed_nodes))
  
  --print("duganode")
  --print(core.serialize(core.registered_nodes[oldnode.name].node_box))
end)

function herob.update_player_bases()
  for _,player in pairs(core.get_connected_players()) do
    local name = player:get_player_name()
    local meta = player:get_meta()
    local placed_nodes = core.deserialize(meta:get_string("placed_nodes"))
    if not placed_nodes then return end
  
    local identified_bases = herob.dbscan_base_decider(placed_nodes, BASE_EPSILON, MIN_BASE_BLOCKS)

    herob.all_bases[name] = identified_bases
    
    --for i,cluster in pairs(herob.all_bases[name]) do
      --print(name.." has a base with "..#cluster.." nodes.")
    --end
    
  end
end


dofile(modname.."/pranks.lua")
