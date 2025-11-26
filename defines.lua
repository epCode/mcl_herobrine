herob.priority_takes = {
  "netherite",
  "netherite",
  "netherite",
  "netherite",
  "netherite",
  "netherite",
  "diamond",
  "diamond",
  "diamond",
  "diamond",
  "diamond",
  "chestplate",
  "chestplate",
  "pick",
  "pick",
  "ender",
  "ender",
  "ender",
  "ingot",
  "ingot",
  "emerald",
  "emerald",
  "obisidian",
  "gold",
  "enchanted",
  "enchanted",
  "enchanted",
  "potion",
  "shulker",
  "shulker",
  "shulker",
}

herob.manmade = {
  "mcl_core:wood",
  "mcl_core:darkwood",
  "mcl_core:junglewood",
  "mcl_core:sprucewood",
  "mcl_core:acaciawood",
  "mcl_core:birchwood",
  "mcl_core:stone_smooth",
  "mcl_core:cobble",
}


herob.lootablechests = {
  "mcl_chests:chest_small",
  "mcl_chests:chest_right",
  "mcl_chests:chest_left",
  "mcl_chests:trapped_chest_small",
  "mcl_chests:trapped_chest_right",
  "mcl_chests:trapped_chest_left",
}

herob.flammable = {}
herob.beds = {}

core.register_on_mods_loaded(function()
  for name,def in pairs(core.registered_nodes) do
    if def.groups.flammable and def.groups.flammable >= 1 then
      table.insert(herob.flammable, name)
    end
    if def.groups.bed and def.groups.bed >= 1 then
      table.insert(herob.beds, name)
    end
  end
end)


herob.torches = {
  "mcl_torches:torch",
  "mcl_torches:torch_wall",
  "mcl_blackstone:soul_torch",
  "mcl_blackstone:soul_torch_wall",
}
