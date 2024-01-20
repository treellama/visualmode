-- Visual Mode.lua
-- A Lua script to enable in-game texture editing
-- By Irons and Smith
-- Released under the JUICE LICENSE!

-- user configurable stuff here

walls = { 17, 18, 19, 20, 21 } 
landscapes = { 27, 28, 29, 30 }

overlay_color = "white"

suppress_items = true
suppress_monsters = true

max_tags = 32
max_scripts = 150

-- snap textures to 1/x WU increments while dragging
snap_denominators = { 4, 5 }

-- choose the position of one of the denominators in the list above if
-- you want snap on by default; 0 is off
default_snap = 0

-- don't modify below this line!

Game.monsters_replenish = not suppress_monsters

CollectionsUsed = {}
for _, collection in pairs(walls) do
   table.insert(CollectionsUsed, collection)
end
for _, collection in pairs(landscapes) do
   table.insert(CollectionsUsed, collection)
end

transfer_modes = { TransferModes["normal"], TransferModes["pulsate"], TransferModes["wobble"], TransferModes["fast wobble"], TransferModes["landscape"], TransferModes["horizontal slide"], TransferModes["fast horizontal slide"], TransferModes["vertical slide"], TransferModes["fast vertical slide"], TransferModes["wander"], TransferModes["fast wander"], TransferModes["static"] }

-- short names for transfer modes
TransferModes["normal"]._short = "normal"
TransferModes["pulsate"]._short = "pulsate"
TransferModes["wobble"]._short = "wobble"
TransferModes["fast wobble"]._short = "f wobble"
TransferModes["landscape"]._short = "landscap"
TransferModes["horizontal slide"]._short = "h slide"
TransferModes["fast horizontal slide"]._short = "fh slide"
TransferModes["vertical slide"]._short = "v slide"
TransferModes["fast vertical slide"]._short = "fv slide"
TransferModes["wander"]._short = "wander"
TransferModes["fast wander"]._short = "f wander"
TransferModes["static"]._short = "static"

VERBOSE = true
TICKS_BETWEEN_INCREMENT = 1

TRIGGER_DELAY = 4

function quantize(player, value)
   if player._quantize == 0 then
      return value
   end

   local ratio = 1.0 / snap_denominators[player._quantize]
   return math.floor(value / ratio + 0.5) * ratio
end   

function find_line_intersection(line, x0, y0, z0, x1, y1, z1)
   local dx = x1 - x0
   local dy = y1 - y0
   local dz = z1 - z0

   local ldx = line.endpoints[1].x - line.endpoints[0].x
   local ldy = line.endpoints[1].y - line.endpoints[0].y
   local t
   if ldx * dy - ldy * dx == 0 then
      t = 0
   else 
      t = (ldx * (line.endpoints[0].y - y0) + ldy * (x0 - line.endpoints[0].x)) / (ldx * dy - ldy * dx)
   end

   return x0 + t * dx, y0 + t * dy, z0 + t * dz
end

function find_floor_or_ceiling_intersection(height, x0, y0, z0, x1, y1, z1)
   local dx = x1 - x0
   local dy = y1 - y0
   local dz = z1 - z0

   local t
   if dz == 0 then
      t = 0
   else
      t = (height - z0) / dz
   end

   return x0 + t * dx, y0 + t * dy, z
end

function find_target(player, find_first_line, find_first_side)
   local polygon = player.monster.polygon
   local x0, y0, z0 = player.x, player.y, player.z + 0.6
   local x1, y1, z1 = x0, y0, z0
   local dx = math.cos(math.rad(player.pitch)) * math.cos(math.rad(player.yaw))
   local dy = math.cos(math.rad(player.pitch)) * math.sin(math.rad(player.yaw))
   local dz = math.sin(math.rad(player.pitch))

   local line

   x1 = x1 + dx
   y1 = y1 + dy
   z1 = z1 + dz
   repeat
      line = polygon:find_line_crossed_leaving(x0, y0, x1, y1)

      if line then
	 local x, y, z = find_line_intersection(line, x0, y0, z0, x1, y1, z1)
	 if z > polygon.ceiling.height then
	    x, y, z = find_floor_or_ceiling_intersection(polygon.ceiling.height, x0, y0, z0, x1, y1, z1)
	    return polygon.ceiling, x, y, z, polygon
	 elseif z < polygon.floor.height then
	    x, y, z = find_floor_or_ceiling_intersection(polygon.ceiling.height, x0, y0, z0, x1, y1, z1)
	    return polygon.floor, x, y, z, polygon
	 else
	    local opposite_polygon
	    if line.clockwise_polygon == polygon then
	       opposite_polygon = line.counterclockwise_polygon
	    elseif line.counterclockwise_polygon == polygon then
	       opposite_polygon = line.clockwise_polygon
	    end

	    if not opposite_polygon or find_first_line then
	       -- always stop
	       -- locate the side
	       if line.clockwise_polygon == polygon then
		  if line.clockwise_side then
		     return line.clockwise_side, x, y, z, polygon
		  else
		     return line, x, y, z, polygon
		  end
	       else
		  if line.counterclockwise_side then
		     return line.counterclockwise_side, x, y, z, polygon
		  else
		     return line, x, y, z, polygon
		  end
	       end
	    elseif find_first_side and line.has_transparent_side then
	       if line.clockwise_polygon == polygon then
		  return line.clockwise_side, x, y, z, polygon
	       else
		  return line.counterclockwise_side, x, y, z, polygon
	       end
	    else
	       -- can we pass
	       if z < opposite_polygon.floor.height or z > opposite_polygon.ceiling.height then
		  if line.clockwise_polygon == polygon then
		     if line.clockwise_side then
			return line.clockwise_side, x, y, z, polygon
		     else
			return line, x, y, z, polygon
		     end
		  else
		     if line.counterclockwise_side then
			return line.counterclockwise_side, x, y, z, polygon
		     else
			return line, x, y, z, polygon
		     end
		  end
	       else
		  -- pass
		  polygon = opposite_polygon
	       end
	    end
	 end
      else
	 -- check if we hit the floor, or ceiling
	 if z1 > polygon.ceiling.height then
	    local x, y, z = find_floor_or_ceiling_intersection(polygon.ceiling.height, x0, y0, z0, x1, y1, z1)
	    return polygon.ceiling, x, y, z, polygon
	 elseif z1 < polygon.floor.height then
	    local x, y, z = find_floor_or_ceiling_intersection(polygon.floor.height, x0, y0, z0, x1, y1, z1)
	    return polygon.floor, x, y, z, polygon
	 else
	    x1 = x1 + dx
	    y1 = y1 + dy
	    z1 = z1 + dz
	 end
      end
   until x1 > 32 or x1 < -32 or y1 > 32 or y1 < -32 or z1 > 32 or z1 < -32
   -- uh oh
   print("POOP!")
   return nil
end
	 
function set_collection(player, collection)
   if player._collection ~= collection then
      if collection == 0 then
	 -- not really interface, landscape!
	 player.texture_palette.size = #landscape_palette
	 if player.local_ then
	    for i = 1, #landscape_palette do
	       player.texture_palette.slots[i - 1].collection = landscape_palette[i].collection
	       player.texture_palette.slots[i - 1].texture_index = landscape_palette[i].texture_index
	       if Game.version >= "20090801" then
		  player.texture_palette.slots[i - 1].type = TextureTypes["landscape"]
	       end
	    end
	 end
	 if player._texture >= #landscape_palette then
	    player._texture = 0
	 end
      else
	 player.texture_palette.size = collection.bitmap_count
	 if player.local_ then
	    for i = 0, collection.bitmap_count - 1 do
	       player.texture_palette.slots[i].collection = collection
	       player.texture_palette.slots[i].texture_index = i
	       if Game.version >= "20090801" then
		  player.texture_palette.slots[i].type = TextureTypes["wall"]
	       end
	    end
	 end
	 if player._texture >= collection.bitmap_count then
	    player._texture = 0
	 end
      end
      player._collection = collection
   end
end

function get_clockwise_side_endpoint(side)
   local line_is_clockwise = true
   if side.line.clockwise_polygon ~= side.polygon then
      -- counterclockwise line
      return side.line.endpoints[0]
   else
      return side.line.endpoints[1]
   end
end

function get_counterclockwise_side_endpoint(side)
   local line_is_clockwise = true
   if side.line.clockwise_polygon ~= side.polygon then
      -- counterclockwise line
      return side.line.endpoints[1]
   else
      return side.line.endpoints[0]
   end
end

-- returns primary_side, secondary_side, or transparent_side
function side_surface(side, z)
   if side.type == "full" then
      local opposite_polygon
      if side.line.clockwise_side == side then
	 opposite_polygon = side.line.counterclockwise_polygon
      else
	 opposite_polygon = side.line.clockwise_polygon
      end
      if opposite_polygon then
	 return side.transparent
      else
	 return side.primary
      end
   elseif side.type == "high" then
      if z > side.line.lowest_adjacent_ceiling then
	 return side.primary
      else
	 return side.transparent
      end
   elseif side.type == "low" then
      if z < side.line.highest_adjacent_floor then
	 return side.primary
      else
	 return side.transparent
      end
   else
      if z > side.line.lowest_adjacent_ceiling then
	 return side.primary
      elseif z < side.line.highest_adjacent_floor then
	 return side.secondary
      else
	 return side.transparent
      end
   end
end

function surface_heights(surface)
   local side = Sides[surface.index]
   if is_primary_side(surface) then
      if side.type == "full" then
	 return side.polygon.floor.height, side.polygon.ceiling.height
      elseif side.type == "low" then
	 return side.polygon.floor.height, side.line.highest_adjacent_floor
      else
	 return side.line.lowest_adjacent_ceiling, side.polygon.ceiling.height
      end
   elseif is_secondary_side(surface) then
      if side.type == "split" then
	 return side.polygon.floor.height, side.line.highest_adjacent_floor
      else
	 return nil
      end
   else -- transparent
      if side.type == "full" then
	 return side.polygon.floor.height, side.polygon.ceiling.height
      elseif side.type == "low" then
	 return side.line.highest_adjacent_floor, side.polygon.ceiling.height
      elseif side.type == "high" then
	 return side.polygon.floor.height, side.line.lowest_adjacent_ceiling
      else -- split
	 return side.line.highest_adjacent_floor, side.line.lowest_adjacent_ceiling
      end
   end
end
   
function apply_texture(player, surface, texture_x, texture_y)
   if player._apply_textures then
      if player._collection == 0 then
	 surface.collection = landscape_palette[player._texture + 1].collection
	 surface.texture_index = landscape_palette[player._texture + 1].texture_index
	 surface.transfer_mode = "landscape"
      else
	 surface.collection = player._collection
	 surface.texture_index = player._texture
	 surface.transfer_mode = player._transfer
      end
      surface.texture_x = texture_x
      surface.texture_y = texture_y
   end
   if player._apply_lights then
      surface.light = Lights[player._light]
   end
end

function build_undo(surface)
   local collection = surface.collection
   local texture_index = surface.texture_index
   local transfer_mode = surface.transfer_mode
   local light = surface.light
   local texture_x = surface.texture_x
   local texture_y = surface.texture_y
   local empty = is_transparent_side(surface) and surface.empty
   local device
   if is_primary_side(surface) then
      local side = Sides[surface.index]
      if side.control_panel then
	 device = {}
	 device.device = side.control_panel.type
	 device.light_dependent = side.control_panel.light_dependent
	 device.permutation = side.control_panel.permutation
	 device.only_toggled_by_weapons = side.control_panel.only_toggled_by_weapons
	 device.repair = side.control_panel.repair
	 device.status = side.control_panel.status
      end
   end
   local function undo()
      if empty then
	 surface.empty = true
      else
	 if collection then
	    surface.collection = collection
	 end
	 surface.texture_index = texture_index
	 surface.transfer_mode = transfer_mode
	 surface.light = light
	 if device then
	    save_control_panel(Sides[surface.index], device)
	 elseif is_primary_side(surface) then
	    Sides[surface.index].control_panel = false
	 end
      end
      surface.texture_x = texture_x
      surface.texture_y = texture_y
   end
   return undo
end

function undo(player)
   if not player._undo then return end
   local redo = {}
   for s, f in pairs(player._undo) do
      redo[s] = build_undo(s)
      f()
   end
   player._undo = redo
end

function copy_texture(player, surface)
   if is_transparent_side(surface) and surface.empty then return end
   for _, v in pairs(landscapes) do
      if surface.collection == v then
	 -- find it in the landscape palette
	 for index, entry in pairs(landscape_palette) do
	    if surface.collection == entry.collection 
	       and surface.texture_index == entry.texture_index 
	    then
	       player._texture = index - 1
	       set_collection(player, Collections[0])
	       player._light = surface.light.index
	       return
	    end
	 end
      end
   end

   player._texture = surface.texture_index
   player._transfer = surface.transfer_mode
   set_collection(player, surface.collection)
   player._light = surface.light.index
end

function valid_surfaces(side) 
   local surfaces = {}
   if side.type == "split" then
      table.insert(surfaces, side.primary)
      table.insert(surfaces, side.secondary)
      table.insert(surfaces, side.transparent)
   elseif side.type == "full" then
      table.insert(surfaces, side.primary)
   else
      table.insert(surfaces, side.primary)
      table.insert(surfaces, side.transparent)
   end
   return surfaces
end

function build_side_offsets_table(first_surface)
   local surfaces = {}
   local offsets = {} -- surface -> offset

   table.insert(surfaces, first_surface)
   offsets[first_surface] = 0

   while # surfaces > 0 do
      -- remove the first surface
      local surface = table.remove(surfaces, 1)
      local low, high = surface_heights(surface)
      
      local side = Sides[surface.index]

      -- consider neighboring surfaces on this side
      local neighbors = {}
      
      if side.type == "split" then
	 if is_transparent_side(surface) then
	    table.insert(neighbors, side.primary)
	    table.insert(neighbors, side.secondary)
	 else
	    -- check for "joined" split
	    local bottom, top = surface_heights(side.transparent)
	    if bottom == top then
	       if is_primary_side(surface) then
		  table.insert(neighbors, side.secondary)
	       else
		  table.insert(neighbors, side.primary)
	       end
	    else
	       table.insert(neighbors, side.transparent)
	    end
	 end
      elseif side.type ~= "full" then
	 if is_primary_side(surface) then
	    table.insert(neighbors, side.transparent)
	 elseif is_transparent_side(surface) then
	    table.insert(neighbors, side.primary)
	 end
      end

      for _, neighbor in pairs(neighbors) do
	 if offsets[neighbor] == nil 
	    and surface.texture_index == neighbor.texture_index
	    and surface.collection == neighbor.collection
	 then
	    offsets[neighbor] = offsets[surface]
	    table.insert(surfaces, neighbor)
	 end
      end

      local line = Sides[surface.index].line
      local length = line.length
      -- consider any clockwise adjacent surfaces within our height range
      for _, side in pairs(ccw_endpoint_sides[get_clockwise_side_endpoint(Sides[surface.index])]) do
	 if side.line ~= line then
	    for _, neighbor_surface in pairs(valid_surfaces(side)) do
	       local bottom, top = surface_heights(neighbor_surface)
	       if offsets[neighbor_surface] == nil
		  and neighbor_surface.texture_index == surface.texture_index
		  and neighbor_surface.collection == surface.collection
		  and high > bottom and top > low
	       then
		  offsets[neighbor_surface] = offsets[surface] + length
		  table.insert(surfaces, neighbor_surface)
	       end
	    end
	 end
      end

      -- consider any counterclockwise adjacent surfaces within our height range
      for _, side in pairs(cw_endpoint_sides[get_counterclockwise_side_endpoint(Sides[surface.index])]) do

	 if side.line ~= line then
	    for _, neighbor_surface in pairs(valid_surfaces(side)) do
	       local bottom, top = surface_heights(neighbor_surface)
	       if offsets[neighbor_surface] == nil
		  and neighbor_surface.texture_index == surface.texture_index
		  and neighbor_surface.collection == surface.collection
		  and high > bottom and top > low
	       then
		  offsets[neighbor_surface] = offsets[surface] - side.line.length
		  table.insert(surfaces, neighbor_surface)
	       end
	    end
	 end
      end
   end
   
   return offsets
end

function align_sides(surface, offsets)
   local x = surface.texture_x
   local y = surface.texture_y
   local _, top = surface_heights(surface)

   for surface, offset in pairs(offsets) do
      local _, new_top = surface_heights(surface)
      surface.texture_x = x + offset
      surface.texture_y = y + top - new_top
   end
end

function build_polygon_align_table(polygon, surface)
   local polygons = {}
   local accessor
   if is_polygon_floor(surface) then
      accessor = "floor"
   else
      accessor = "ceiling"
   end

   local function recurse(p)
      if not polygons[p] -- already visited
	 and p[accessor].texture_index == surface.texture_index 
	 and p[accessor].collection == surface.collection 
	 and p[accessor].z == surface.z
      then
	 -- add this polygon, and search for any adjacent
	 polygons[p] = true
	 for adjacent in p:adjacent_polygons() do
	    recurse(adjacent)
	 end
      end
   end

   recurse(polygon)
   return polygons
end

function align_polygons(surface, align_table)
   local x = surface.texture_x
   local y = surface.texture_y
   
   local accessor
   if is_polygon_floor(surface) then
      accessor = "floor"
   else
      accessor = "ceiling"
   end
   for p in pairs(align_table) do
      p[accessor].texture_x = x
      p[accessor].texture_y = y
   end
end

function interleave_icons(icon1, icon2)
   result = ""
   for i = 1, 8 do
      result = result .. icon1[i] .. icon2[i] .. "\n"
   end
   
   return result
end

function build_texture_icon(player)
   local texture, light, align, transparent

   if player._apply_textures then
      texture = icon_textures
   else 
      texture = icon_empty
   end

   if player._apply_lights then
      light = icon_lights
   else
      light = icon_empty
   end

   if player._apply_aligned and player._apply_textures then
      align = icon_align
   else
      align = icon_empty
   end

   if player._apply_transparent then
      transparent = icon_transparent
   else
      transparent = icon_empty
   end

   player._texture_icon = icon_status_colors .. interleave_icons(texture, light) .. interleave_icons(align, transparent)
end

Modes = {}

Modes.texture = {}
Modes.move = {}
Modes.device = {}

Modes.texture.next = Modes.move
Modes.move.next = Modes.texture

Modes.texture.name = "texture"
Modes.move.name = "move"
Modes.device.name = "device"

function Modes.texture.handle(p)
   -- handle undo and mode change
   if p.action_flags.action_trigger then
      if p.action_flags.microphone_button then
	 p.action_flags.action_trigger = false
	 undo(p)
	 return
      elseif not p:find_action_key_target() then
	 p.action_flags.action_trigger = false
	 p._mode = Modes.move
	 return
      end
   end

   if p._overhead then
      if p.action_flags.microphone_button then

	 -- n: cycle modes forward
	 if p.action_flags.cycle_weapons_forward then
	    p.action_flags.cycle_weapons_forward = false
	    
	    local index
	    -- find this transfer mode
	    for i, mode in ipairs(transfer_modes) do
	       if mode == p._transfer then
		  index = i
		  break
	       end
	    end
	    p._transfer = transfer_modes[(index % #transfer_modes) + 1]
	 end

	 -- p: cycle modes backward
	 if p.action_flags.cycle_weapons_backward then
	    p.action_flags.cycle_weapons_backward = false
	    
	    local index
	    -- find this transfer mode
	    for i, mode in ipairs(transfer_modes) do
	       if mode == p._transfer then
		  index = i
		  break
	       end
	    end
	    p._transfer = transfer_modes[((index - 2) % #transfer_modes) + 1]
	 end

	 -- t1: toggle edit devices
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	       p._edit_control_panels = not p._edit_control_panels
	    end
	 else
	    p._trigger_release.left_trigger = false
	 end

	 -- t2: quantize
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    if not p._trigger_release.right_trigger then
	       p._trigger_release.right_trigger = true
	       p._quantize = (p._quantize + 1) % (# snap_denominators + 1)
	    end
	 else
	    p._trigger_release.right_trigger = false
	 end

	 p.overlays[2].text = "transfer-"
	 p.overlays[3].text = "transfer+"
	 
	 if p._edit_control_panels then
	    p.overlays[4].text = "edit panels"
	 else
	    p.overlays[4].text = "no panels"
	 end
	 if p._quantize == 0 then
	    p.overlays[5].text = "no snap"
	 else
	    p.overlays[5].text = "snap 1/" .. tostring(snap_denominators[p._quantize])
	 end
      else
	 -- n: toggle apply textures
	 if p.action_flags.cycle_weapons_forward then
	    p.action_flags.cycle_weapons_forward = false
	    p._apply_textures = not p._apply_textures
	    build_texture_icon(p)
	 end

	 -- p: toggle apply lights
	 if p.action_flags.cycle_weapons_backward then
	    p.action_flags.cycle_weapons_backward = false
	    p._apply_lights = not p._apply_lights
	    build_texture_icon(p)
	 end

	 -- t1: toggle apply aligned
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	       p._apply_aligned = not p._apply_aligned
	       build_texture_icon(p)
	    end
	 else
	    p._trigger_release.left_trigger = false
	 end

	 -- t2: toggle apply transparent
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    if not p._trigger_release.right_trigger then
	       p._trigger_release.right_trigger = true
	       p._apply_transparent = not p._apply_transparent
	       build_texture_icon(p)
	    end
	 else
	    p._trigger_release.right_trigger = false
	 end

	 if p._apply_textures then
	    p.overlays[3].text = "apply tex"
	 else
	    p.overlays[3].text = "no textures"
	 end

	 if p._apply_lights then
	    p.overlays[2].text = "apply light"
	 else
	    p.overlays[2].text = "no lights"
	 end

	 if p._apply_aligned then
	    p.overlays[4].text = "aligned"
	 else
	    p.overlays[4].text = "not aligned"
	 end

	 if p._apply_transparent then
	    p.overlays[5].text = "transparent"
	 else
	    p.overlays[5].text = "solid"
	 end
      end
   else
      if p.action_flags.microphone_button then
	 p.crosshairs.active = false

	 -- n: cycle texture collections forward
	 if p.action_flags.cycle_weapons_forward then
	    p.action_flags.cycle_weapons_forward = false
	    -- find the collection in walls
	    local index
	    for i, v in ipairs(walls) do
	       if v == p._collection.index then
		  index = i
		  break
	       end
	    end
	    local collection_index = walls[(index % #walls) + 1]
	    set_collection(p, Collections[collection_index])
	 end

	 -- p: cycle texture collections backward
	 if p.action_flags.cycle_weapons_backward then
	    p.action_flags.cycle_weapons_backward = false
	    local index
	    for i, v in ipairs(walls) do
	       if v == p._collection.index then
		  index = i
		  break
	       end
	    end
	    local collection_index = walls[((index - 2) % #walls) + 1]
	    set_collection(p, Collections[collection_index])
	 end

	 -- t1: increment texture
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	       p._increment_texture = Game.ticks
	    end
	    if Game.ticks == p._increment_texture 
	       or Game.ticks > p._increment_texture + TRIGGER_DELAY 
	    then
	       if p._collection.index == 0 then
		  p._texture = (p._texture + 1) % #landscape_palette
	       else
		  p._texture = (p._texture + 1) % p._collection.bitmap_count
	       end
	    end
	 else
	    p._trigger_release.left_trigger = false
	 end

	 -- t2: decrement texture
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    if not p._trigger_release.right_trigger then
	       p._trigger_release.right_trigger = true
	       p._decrement_texture = Game.ticks
	    end
	    if Game.ticks == p._decrement_texture
	       or Game.ticks > p._decrement_texture + TRIGGER_DELAY
	    then
	       if p._collection == 0 then
		  p._texture = (p._texture - 1) % #landscape_palette
	       else
		  p._texture = (p._texture - 1) % p._collection.bitmap_count
	       end
	    end
	 else
	    p._trigger_release.right_trigger = false
	 end

	 p.overlays[3].text = "collection+"
	 p.overlays[2].text = "collection-"
	 p.overlays[4].text = "texture+"
	 p.overlays[5].text = "texture-"

	 -- Toggle transparent side edit
      else
	 p.crosshairs.active = true

	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	       -- apply texture, and start dragging
	       local surface
	       local o, x, y, z, polygon = find_target(p, p._apply_transparent, false)
	       if is_side(o) then
		  o:recalculate_type()
		  surface = side_surface(o, z)
	       elseif is_polygon_floor(o) or is_polygon_ceiling(o) then
		  surface = o
	       elseif is_polygon(o) then
		  surface = o.floor
	       elseif is_line(o) then
		  -- we need to make a new side
		  surface = side_surface(Sides.new(polygon, o), z)
	       end
	       
	       if surface then
		  if p._apply_textures then
		     local dragging = {}
		     if surface.texture_index == p._texture and surface.collection == p._collection then
			dragging.x = surface.texture_x
			dragging.y = surface.texture_y
		     else
			dragging.x = 0
			if is_side(o) then
			   local bottom, top = surface_heights(surface)
			   dragging.y = bottom - top
			else
			   dragging.y = 0
			end
		     end
		     dragging.yaw = p.yaw
		     dragging.pitch = p.pitch
		     dragging.surface = surface
		     dragging.start = Game.ticks
		     p._undo = {}
		     p._undo[surface] = build_undo(surface)
		     apply_texture(p, surface, dragging.x, dragging.y)
		     if is_transparent_side(surface) then
			-- put the same texture on the opposite side of the line
			local side = Sides[surface.index]
			local line = side.line
			if line.clockwise_side == side then
			   if line.counterclockwise_side then
			      dragging.opposite_surface = line.counterclockwise_side.transparent
			   elseif line.counterclockwise_polygon then
			      dragging.opposite_surface = Sides.new(line.counterclockwise_polygon, line).transparent
			   end
			else
			   if line.clockwise_side then
			      dragging.opposite_surface = line.clockwise_side.transparent
			   elseif line.clockwise_polygon then
			      dragging.opposite_surface = Sides.new(line.clockwise_polygon, line).transparent
			   end
			end

			if dragging.opposite_surface then
			   p._undo[dragging.opposite_surface] = build_undo(dragging.opposite_surface)
			   apply_texture(p, dragging.opposite_surface, -dragging.x, dragging.y)
			end
		     end
		     if p._apply_aligned then
			if is_polygon_floor(surface) or is_polygon_ceiling(surface) then
			   dragging.align_table = build_polygon_align_table(polygon, surface)
			   if is_polygon_floor(surface) then
			      for s in pairs(dragging.align_table) do
				 if not p._undo[s.floor] then
				    p._undo[s.floor] = build_undo(s.floor)
				 end
			      end
			   else
			      for s in pairs(dragging.align_table) do
				 if not p._undo[s.ceiling] then
				    p._undo[s.ceiling] = build_undo(s.ceiling)
				 end
			      end
			   end
			   align_polygons(surface, dragging.align_table)
			else
			   dragging.offsets = build_side_offsets_table(surface)
			   for s in pairs(dragging.offsets) do
			      if not p._undo[s] then 
				 p._undo[s] = build_undo(s)
			      end
			   end
			   align_sides(surface, dragging.offsets)
			   if dragging.opposite_surface then
			      dragging.opposite_offsets = build_side_offsets_table(dragging.opposite_surface)
--			      for s in pairs(dragging.offsets) do
--				 dragging.opposite_offsets[s] = nil
--			      end
			      for s in pairs(dragging.opposite_offsets) do
				 if not p._undo[s] then 
				    p._undo[s] = build_undo(s)
				 end
			      end
			      align_sides(dragging.opposite_surface, dragging.opposite_offsets)
			   end
			end
		     end
		     p._dragging = dragging
		  elseif p._apply_lights then
		     p._undo = {}
		     p._undo[surface] = build_undo(surface)
		     apply_texture(p, surface)
		  end	  
	       end
	    elseif p._dragging and Game.ticks > p._dragging.start + 3 then
	       if is_polygon_floor(p._dragging.surface) or is_polygon_ceiling(p._dragging.surface) then
		  -- pitch slides texture parallel to player's initial yaw
		  -- yaw slides texture perpendicular to player's initial yaw
		  -- this isn't great, but hopefully it's enough
		  local delta_pitch = p._dragging.pitch - p.pitch
		  if is_polygon_ceiling(p._dragging.surface) then
		     delta_pitch = -delta_pitch
		  end
		  local delta_yaw = p._dragging.yaw - p.yaw
		  local x = p._dragging.x - delta_yaw / 180 * math.sin(math.rad(p.yaw))
		  local y = p._dragging.y + delta_yaw / 180 * math.cos(math.rad(p.yaw))

		  x = quantize(p, x + delta_pitch / 60 * math.cos(math.rad(p.yaw)))
		  y = quantize(p, y + delta_pitch / 60 * math.sin(math.rad(p.yaw)))
		  apply_texture(p, p._dragging.surface, x, y)
		  if p._apply_aligned then
		     align_polygons(p._dragging.surface, p._dragging.align_table)
		  end
	       else
		  local delta_pitch = p._dragging.pitch - p.pitch
		  local delta_yaw = p._dragging.yaw - p.yaw
		  local x = quantize(p, p._dragging.x + delta_yaw / 90)
		  local y = quantize(p, p._dragging.y - delta_pitch / 60)
		  apply_texture(p, p._dragging.surface, x, y)
		  if p._apply_aligned then
		     align_sides(p._dragging.surface, p._dragging.offsets)
		  end
		  if p._dragging.opposite_surface then
		     apply_texture(p, p._dragging.opposite_surface, -x, y)
		     if p._apply_aligned then
			align_sides(p._dragging.opposite_surface, p._dragging.opposite_offsets)
		     end
		  end
	       end
	    end
	 elseif p._trigger_release.left_trigger then
	    -- release
	    p._trigger_release.left_trigger = false
	    if p._apply_textures and is_primary_side(p._dragging.surface) then
	       if device_collections[p._collection]
		  and device_collections[p._collection][p._texture]
	       then
		  if p._edit_control_panels then
		     Modes.device.enter(p, Sides[p._dragging.surface.index])
		  end
	       else
		  Sides[p._dragging.surface.index].control_panel = false
	       end
	    end
	    p._dragging = nil
	 end

	 -- Copy texture (only when trigger is released)
	 if not p.action_flags.right_trigger and
	    p._trigger_release.right_trigger then
	    p._trigger_release.right_trigger = false
	    p.action_flags.right_trigger = false
	    local o,_,_,z = find_target(p, false, p._apply_transparent)
	    if is_side(o) then
	       copy_texture(p, side_surface(o, z))
	    elseif is_polygon_floor(o) or is_polygon_ceiling(o) then
	       copy_texture(p, o)
	    elseif is_polygon(o) then
	       copy_texture(p, o.floor)
	    end
	 end
	 -- t1: copy selected texture and light
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    p._trigger_release.right_trigger = true
	 end -- end texture copy

	 -- n: increment light
	 if p.action_flags.cycle_weapons_forward then
	    p.action_flags.cycle_weapons_forward = false
	    p._light = (p._light + 1) % #Lights
	 end
	 
	 -- p: decrement light
	 if p.action_flags.cycle_weapons_backward then
	    p.action_flags.cycle_weapons_backward = false
	    p._light = (p._light - 1) % #Lights
	 end

	 p.overlays[3].text = "light+"
	 p.overlays[2].text = "light-"

	 p.overlays[4].text = "apply"
	 p.overlays[5].text = "copy"
      end 
   end

   if p.action_flags.microphone_button then
      p.overlays[0].text = "undo"
   else
      p.overlays[0].text = "texture"
   end

   p.overlays[1].icon = p._texture_icon
   p.overlays[1].text = p._light .. " " .. p._transfer._short
   if p.local_ then p.texture_palette.highlight = p._texture end

end

function Modes.move.handle(p)
   p.crosshairs.active = false

   -- handle undo and mode changes
   if p.action_flags.action_trigger then
      if p.action_flags.microphone_button then
	 p.action_flags.action_trigger = false
	 undo(p)
	 return
      else
	 if not p:find_action_key_target() then
	    p.action_flags.action_trigger = false
	    p._mode = Modes.texture
	 end
	 return
      end
   end

   if p._overhead then
      p.overlays[3].text = ""
      p.overlays[2].text = ""
      p.overlays[4].text = ""
      p.overlays[5].text = ""
      -- nothing yet
   else
      if p.action_flags.microphone_button then

	 p.overlays[4].text = "poly+"
	 -- mic + t1: increment polygon
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	       p._increment = Game.ticks
	    end
	    if Game.ticks == p._increment 
	       or Game.ticks > p._increment + TRIGGER_DELAY
	    then
	       p._polygons.selected = 
		  Polygons[(p._polygons.selected.index + 1) % #Polygons]
	    end
	 else
	    p._trigger_release.left_trigger = false
	 end
	 
	 p.overlays[5].text = "poly-"
	 -- mic + t2: decrement polygon
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    if not p._trigger_release.right_trigger then
	       p._trigger_release.right_trigger = true
	       p._decrement = Game.ticks
	    end
	    if Game.ticks == p._decrement 
	       or Game.ticks > p._decrement + TRIGGER_DELAY
	    then
	       p._polygons.selected = 
		  Polygons[(p._polygons.selected.index - 1) % #Polygons]
	    end
	 else
	    p._trigger_release.right_trigger = false
	 end

	 p.overlays[3].text = " "
	 p.overlays[2].text = " "

      else

	 p.overlays[4].text = "teleport"
	 -- t1 down
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    p._trigger_release.left_trigger = true
	 elseif p._trigger_release.left_trigger then
	    -- t1 release: teleport
	    p._trigger_release.left_trigger = false
	    p.action_flags.left_trigger = false
	    p:teleport(p._polygons.selected)
	    p._freeze = false
	 end

	 p.overlays[5].text = "select poly"
	 -- t2: down
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    p._trigger_release.right_trigger = true
	    p.crosshairs.active = true
	 elseif p._trigger_release.right_trigger then
	    -- t2 release: select poly
	    p._trigger_release.right_trigger = false
	    local t,x,y,z,poly = p:find_target()
	    p._polygons.selected = poly
	 end 

	 p.overlays[3].text = "jump"
	 -- n: jump
	 if p.action_flags.cycle_weapons_forward then
	    p.action_flags.cycle_weapons_forward = false
	    p:accelerate(0, 0, 0.05)
	 end

	 if p._freeze then
	    p.overlays[2].text = "unfreeze"
	 else
	    p.overlays[2].text = "freeze"
	 end
	 -- p: toggle freeze
	 if p.action_flags.cycle_weapons_backward then
	    p.action_flags.cycle_weapons_backward = false
	    p._freeze = not p._freeze
	    p._point.x = p.x
	    p._point.y = p.y
	    p._point.z = p.z
	    p._point.poly = p.polygon
	 end

      end

   end

   -- set the mode overlays
   if p.action_flags.microphone_button then
      p.overlays[0].text = "undo"
   else
      p.overlays[0].text = "move"
   end

   p.overlays[1].icon = icon_forge
   p.overlays[1].text = "polygon " .. p._polygons.selected.index

end

function is_switch(device)
   return device.class == "light switch" or device.class == "tag switch" or device.class == "platform switch"
end

function save_control_panel(side, device)
   side.control_panel = true
   side.control_panel.light_dependent = device.light_dependent
   side.control_panel.permutation = device.permutation
   if is_switch(device.device) then
      side.control_panel.only_toggled_by_weapons = device.only_toggled_by_weapons
      side.control_panel.repair = device.repair
      side.control_panel.can_be_destroyed = (device.device._type == "wires")
      side.control_panel.uses_item = (device.device._type == "chip insertion")
      if device.device.class == "light switch" then
	 side.control_panel.status = Lights[side.control_panel.permutation].active
      elseif device.device.class == "platform_switch" then
	 side.control_panel.status = Polygons[side.control_panel.permutation].platform.active
      else
	 side.control_panel.status = device.status
      end
   else
      side.control_panel.only_toggled_by_weapons = false
      side.control_panel.repair = false
      side.control_panel.can_be_destroyed = false
      side.control_panel.uses_item = false
      side.control_panel.status = false
   end
   side.control_panel.type = device.device
end

function Modes.device.enter(p, side)
   p._device = {}
   p._device.side = side
   if side.control_panel 
      and side.control_panel.type.collection == p._collection 
      and (side.control_panel.type.active_texture_index == p._texture or side.control_panel.type.inactive_texture_index == p._texture)
   then
      -- copy in the info
      p._device.device = side.control_panel.type
      p._device.light_dependent = side.control_panel.light_dependent
      p._device.only_toggled_by_weapons = side.control_panel.only_toggled_by_weapons
      p._device.repair = side.control_panel.repair
      p._device.status = side.control_panel.status

      if side.control_panel.type.class == "tag switch" then
	 p._device_tag = side.control_panel.permutation
      elseif side.control_panel.type.class == "light switch" then
	 p._device_light = side.control_panel.permutation
      elseif side.control_panel.type.class == "platform switch" then
	 p._device_platform = 1
	 for key, plat in pairs(sorted_platforms) do
	    if plat.polygon.index == side.control_panel.permutation then
	       p._device_platform = key
	    end
	 end
      elseif side.control_panel.type.class == "terminal" then
	 p._device_script = side.control_panel.permutation
      end
   else
      for t in ControlPanelTypes() do
	 if t.collection == p._collection and (t.active_texture_index == p._texture or t.inactive_texture_index == p._texture) and not (# Platforms == 0 and t.class == "platform switch") then
	    p._device.device = t
	    break
	 end
      end
      p._device.light_dependent = false
      p._device.only_toggled_by_weapons = false
      p._device.repair = false
      p._device.status = p._device.device.active_texture_index == p._texture
   end
   p._mode = Modes.device
end
	 

function Modes.device.handle(p)
   p.crosshairs.active = false
   if p._overhead then
      -- nothing
      for i = 0, 5 do
	 p.overlays[i].text = ""
      end
   else
      if p.action_flags.microphone_button then

	 if is_switch(p._device.device) then

	    -- p: toggle repair
	    if p.action_flags.cycle_weapons_backward then
	       p.action_flags.cycle_weapons_backward = false
	       p._device.repair = not p._device.repair
	    end

	    if p._device.device.class == "tag switch" then
	       -- n: toggle raw status
	       if p.action_flags.cycle_weapons_forward  then
		  p.action_flags.cycle_weapons_forward = false
		  if is_switch(p._device.device) then
		     p._device.status = not p._device.status
		  end
	       end
	    end

	    p.overlays[0].text = " "
	    p.overlays[2].text = "repair"
	    if not p._device.repair then
	       p.overlays[2].color = "dark red"
	    end

	    if p._device.device.class == "tag switch" then
	       p.overlays[3].text = "status"
	       if not p._device.status then
		  p.overlays[3].color = "dark red"
	       end
	    else
	       p.overlays[3].text = " "
	    end
	 else
	    p.overlays[0].text = " "
	    p.overlays[2].text = " "
	    p.overlays[3].text = " "
	 end

	 if p._device.device.class == "tag switch" then
	    p.overlays[4].text = "tag+"
	    p.overlays[5].text = "tag-"
	 elseif p._device.device.class == "light switch" then
	    p.overlays[4].text = "light+"
	    p.overlays[5].text = "light-"
	 elseif p._device.device.class == "platform switch" then
	    p.overlays[4].text = "platform+"
	    p.overlays[5].text = "platform-"
	 elseif p._device.device.class == "terminal" then
	    p.overlays[4].text = "script+"
	    p.overlays[5].text = "script-"
	 else
	    p.overlays[4].text = ""
	    p.overlays[5].text = ""
	 end

	 -- t1: next tag/light/platform/script
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	       p._increment_device = Game.ticks
	    end
	    if Game.ticks == p._increment_device 
	       or Game.ticks > p._increment_device + TRIGGER_DELAY 
	    then
	       if p._device.device.class == "tag switch" then
		  p._device_tag = (p._device_tag + 1) % max_tags
	       elseif p._device.device.class == "light switch" then
		  p._device_light = (p._device_light + 1) % # Lights
	       elseif p._device.device.class == "platform switch" and # Platforms then
		  p._device_platform = p._device_platform % # sorted_platforms + 1
	       elseif p._device.device.class == "terminal" then
		  p._device_script = (p._device_script + 1) % max_scripts
	       end
	    end
	 else
	    p._trigger_release.left_trigger = false
	 end

	 -- t2: previous tag/light/platform/script
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    if not p._trigger_release.right_trigger then
	       p._trigger_release.right_trigger = true
	       p._decrement_device = Game.ticks
	    end
	    if Game.ticks == p._decrement_device 
	       or Game.ticks > p._decrement_device + TRIGGER_DELAY 
	    then
	       if p._device.device.class == "tag switch" then
		  p._device_tag = (p._device_tag - 1) % max_tags
	       elseif p._device.device.class == "light switch" then
		  p._device_light = (p._device_light - 1) % # Lights
	       elseif p._device.device.class == "platform switch" and # Platforms then
		  p._device_platform = ((p._device_platform - 2) % # sorted_platforms) + 1
	       elseif p._device.device.class == "terminal" then
		  p._device_script = (p._device_script - 1) % max_scripts
	       end
	    end
	 else
	    p._trigger_release.right_trigger = false
	 end

      else
	 -- action: switch type
	 if p.action_flags.action_trigger then
	    p.action_flags.action_trigger = false
	    local index = (p._device.device.index + 1) % # ControlPanelTypes
	    while not (ControlPanelTypes[index].collection == p._collection and (ControlPanelTypes[index].active_texture_index == p._texture or ControlPanelTypes[index].inactive_texture_index == p._texture)) or (#Platforms == 0 and ControlPanelTypes[index].class == "platform switch")
	    do
	       index = (index + 1) % # ControlPanelTypes
	    end
	    
	    p._device.device = ControlPanelTypes[index]
	 end

	 -- p: toggle light dependent
	 if p.action_flags.cycle_weapons_backward then
	    p.action_flags.cycle_weapons_backward = false
	    p._device.light_dependent = not p._device.light_dependent
	 end

	 -- n: toggle weapon only
	 if p.action_flags.cycle_weapons_forward  then
	    p.action_flags.cycle_weapons_forward = false
	    if is_switch(p._device.device) then
	       p._device.only_toggled_by_weapons = not p._device.only_toggled_by_weapons
	    end
	 end

	 -- t1: save!
	 if p.action_flags.left_trigger then
	    p.action_flags.left_trigger = false
	    if not p._trigger_release.left_trigger then
	       p._trigger_release.left_trigger = true
	    end
	 elseif p._trigger_release.left_trigger then
	    p._trigger_release.left_trigger = false
	    if p._device.device.class == "tag switch" then
	       p._device.permutation = p._device_tag
	    elseif p._device.device.class == "platform switch" then
	       p._device.permutation = sorted_platforms[p._device_platform].polygon.index
	    elseif p._device.device.class == "light switch" then
	       p._device.permutation = p._device_light
	    elseif p._device.device.class == "terminal" then
	       p._device.permutation = p._device_script
	    else
	       p._device.permutation = -1
	    end
	    save_control_panel(p._device.side ,p._device)
	    p._device = nil
	    p._mode = Modes.texture
	    return
	 end

	 -- t2: cancel apply
	 if p.action_flags.right_trigger then
	    p.action_flags.right_trigger = false
	    if not p._trigger_release.right_trigger then
	       p._trigger_release.right_trigger = true
	       -- clear out the control panel on this side if it's
	       -- incompatible with the chosen texture
	       if p._device.side.primary.collection ~= p._device.device.collection 
		  or not (p._device.side.primary.texture_index == p._device.device.active_texture_index or p._device.side.primary.texture_index == p._device.device.inactive_texture_index)
	       then
		  p._device.side.control_panel = false
	       end
	       p._device = nil
	       p._mode = Modes.texture
	       return
	    end
	 else
	    p._trigger_release.right_trigger = false
	 end

	 p.overlays[2].text = "light dep"
	 if not p._device.light_dependent then
	    p.overlays[2].color = "dark red"
	 end

	 if is_switch(p._device.device) then
	    p.overlays[3].text = "wep only"
	    if not p._device.only_toggled_by_weapons then
	       p.overlays[3].color = "dark red"
	    end
	 else
	    p.overlays[3].text = " "
	 end
	 p.overlays[4].text = "save"
	 p.overlays[5].text = "cancel"

	 p.overlays[0].text = p._device.device._short
      end
   end

   p.overlays[1].icon = icon_forge
   if p._device.device.class == "tag switch" then
      p.overlays[1].text = "tag " .. p._device_tag
   elseif p._device.device.class == "light switch" then
      p.overlays[1].text = "light " .. p._device_light
   elseif p._device.device.class == "platform switch" then
      p.overlays[1].text = "plat " .. sorted_platforms[p._device_platform].polygon.index
   elseif p._device.device.class == "terminal" then
      p.overlays[1].text = "script " .. p._device_script
   else
      p.overlays[1].text = " "
   end

end

Triggers = {}
function Triggers.init()
   if Sides[0] and Sides[0].primary and Sides[0].primary.collection then
      initial_collection = Sides[0].primary.collection
   else
      initial_collection = Collections[walls[1]]
   end

   
   for p in Players() do
      p._texture = 0
      set_collection(p, initial_collection)
      p.texture_palette.highlight = 0
      p._mode = Modes.texture
      p._overhead = false
      p._terminal = false
      p._polygons = {}
      p._polygons.selected = p.polygon
      p._trigger_release = {}
      p._trigger_release.left_trigger = false
      p._trigger_release.right_trigger = false
      p._trigger_release.microphone_button = false
      p._freeze = false
      p._point = {}
      p._point.x = p.x
      p._point.y = p.y
      p._point.x = p.z
      p._point.poly = p.polygon
      p._increment = 0
      p._light = 0
      p._transfer = TransferModes["normal"]
      p._offsets = {}
      p._offsets.x = false
      p._offsets.y = false

      p._apply_lights = true
      p._apply_textures = true
      p._apply_aligned = true
      p._apply_transparent = false
      p._edit_control_panels = true

      p._device_tag = 0
      p._device_light = 0
      p._device_platform = 1
      p._device_script = 0

      p._quantize = default_snap

      build_texture_icon(p)

      p.weapons.active = false

   end

   cw_endpoint_sides = {}
   ccw_endpoint_sides = {}
   for endpoint in Endpoints() do 
      cw_endpoint_sides[endpoint] = {}
      ccw_endpoint_sides[endpoint] = {}
   end
   for side in Sides() do
      table.insert(cw_endpoint_sides[get_clockwise_side_endpoint(side)], side)
      table.insert(ccw_endpoint_sides[get_counterclockwise_side_endpoint(side)], side)
   end 
   
   -- these must be hard-coded into Forge; the engine can't tell them apart
   ControlPanelTypes[3]._type = "chip insertion"
   ControlPanelTypes[9]._type = "wires"
   ControlPanelTypes[19]._type = "chip insertion"
   ControlPanelTypes[20]._type = "wires"
   ControlPanelTypes[30]._type = "chip insertion"
   ControlPanelTypes[31]._type = "wires"
   ControlPanelTypes[41]._type = "chip insertion"
   ControlPanelTypes[42]._type = "wires"
   ControlPanelTypes[52]._type = "chip insertion"
   ControlPanelTypes[53]._type = "wires"

   device_collections = {}
   for t in ControlPanelTypes() do
      if t.collection then
	 if not device_collections[t.collection] then
	    device_collections[t.collection] = {}
	 end
	 device_collections[t.collection][t.active_texture_index] = true
	 device_collections[t.collection][t.inactive_texture_index] = true

	 if t.class == "oxygen recharger" then
	    t._short = "O2 charger"
	 elseif t.class == "single shield recharger" then
	    t._short = "1x charger"
	 elseif t.class == "double shield recharger" then
	    t._short = "2x charger"
	 elseif t.class == "triple shield recharger" then
	    t._short = "3x charger"
	 elseif t.class == "platform switch" then
	    t._short = "platform"
	 elseif t.class == "light switch" then
	    t._short = "light"
	 elseif t.class == "tag switch" and t._type == "chip insertion" then
	    t._short = "chip"
	 elseif t.class == "tag switch" and t._type == "wires" then
	    t._short = "wires"
	 elseif t.class == "tag switch" then
	    t._short = "tag"
	 elseif t.class == "pattern buffer" then
	    t._short = "pat buffer"
	 else 
	    t._short = t.class.mnemonic
	 end
      end
   end

   sorted_platforms = {}
   for platform in Platforms() do
      table.insert(sorted_platforms, platform)
   end
   table.sort(sorted_platforms, function(a, b) return a.polygon.index < b.polygon.index end)

   -- remove missing collections
   local valid_walls = {}
   for _, collection_index in pairs(walls) do
      if Collections[collection_index] then
	 table.insert(valid_walls, collection_index)
      end
   end
   walls = valid_walls

   -- build the landscape palette
   landscape_palette = {}
   for _, collection_index in pairs(landscapes) do
      local c = Collections[collection_index]
      if c then
	 for texture_index = 0, c.bitmap_count - 1 do
	    local landscape_entry = {}
	    landscape_entry.texture_index = texture_index
	    landscape_entry.collection = c
	    table.insert(landscape_palette, landscape_entry)
	 end
      end
   end
   table.insert(walls, 0)

   if suppress_items then
      for item in Items() do 
	 item:delete()
      end

      function Triggers.item_created(item)
	 item:delete()
      end
   end

end

function Triggers.idle()
   if not Sides.new then
      Players.print("Visual Mode.lua requires a newer version of Aleph One")
      kill_script()
      return
   end
   for p in Players() do

      p.life = 450
      p.oxygen = 10800
      -- Make sure overhead state exists
      if p.action_flags.toggle_map then
	 p._overhead = not p._overhead 
      end

      if not p._terminal then
	 for i = 0, 5 do
	    p.overlays[i].color = overlay_color
	 end
	 p._mode.handle(p)
	 p.action_flags.microphone_button = false
      else
	 for i = 0, 5 do
	    p.overlays[i].text = ""
	 end
      end
      
      if Game.ticks == 0 then
	 p.overlays[0].icon = icon_action
	 p.overlays[3].icon = icon_next
	 p.overlays[2].icon = icon_prev
	 p.overlays[4].icon = icon_left
	 p.overlays[5].icon = icon_right
      end

   end --end for p in Players()

end

function Triggers.postidle()
   for p in Players() do
      -- freeze player
      if p._freeze then
	 p:position(p._point.x, p._point.y, p._point.z, p.polygon)
      end
   end
end

function Triggers.terminal_enter(terminal, player)
   if terminal then
      player._terminal = true
   end
end

function Triggers.terminal_exit(_, player)
   player._terminal = false
end

function vp(player, str)
   if VERBOSE then player:print(str) end
end

icon_left = 
[[
7
 000000
.444444
+777777
@FF6633
#CC9966
$BBBBBB
%FFFFFF00
%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%% %
%               
   $ $ ++++++++ 
%               
% #@      %%%%%%
% #@ %%% %%%%%%%
% #@ %%% %%%%%%%
 .#@    %%%%%%%%
 # @ %%%%%%%%%%%
 @@+ %%%%%%%%%%%
    %%%%%%%%%%%%
%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%
]]

icon_right =
[[
9
 222222
.333366
+444444
@555555
#6666CC
$9999FF
%00FFFF00
&CCCCFF
*FFFFFF
%%%%%%%   %%%%%%
%%%%    #   %%%%
%%% % % # %%%%%%
%%% % %@..%%%%%%
%%%  %+    %%%%%
%%%%%+**$#. %%%%
%%%%% *&$#. %%%%
%%%% **$$#.. %%%
%%%% *&$##.. %%%
%%%% &$$##.. %%%
%%%% $$###.. %%%
%%%% $####.. %%%
%%%% ####... %%%
%%%%% ###.. %%%%
%%%%% #.... %%%%
%%%%%%     %%%%%
]]

icon_next =
[[
8
 000000
.DD0000
+777777
@FF6633
#00BB00
$888888
%AAAAAA
&FFFFFF00
&&&&&&&&@..@&&&&
&&&&&&&@.$$.@&&&
&&&&&&@.$$&%.$&&
&&&&&&.$$&&&.$&&
&&&&&&.$&&.....&
&&&&&&.$&&&...$$
&&&&&&.$&&&&.$$&
&&&&&&&$&&&&&$&&
&&&&&&&&&&&&&&&&
   &&    &&    &
 # +& ## +& ## +
 # +& ## +& ## +
 # +& ## +& ## +
 # +& ## +& ## +
   +&    +&    +
&+++&&++++&&++++
]]

icon_prev =
[[
8
 000000
.DD0000
+777777
@FF6633
#00BB00
$888888
%AAAAAA
&FFFFFF00
&&&@..@&&&&&&&&&
&&@.$$.$&&&&&&&&
&&.$$&%.$&&&&&&&
&&.$&&&%.%&&&&&&
.....&&&.$&&&&&&
&...$$&&.$&&&&&&
&&.$$&&&.$&&&&&&
&&&$&&&&&%&&&&&&
&&&&&&&&&&&&&&&&
    &&    &&   &
 ## +& ## +& # +
 ## +& ## +& # +
 ## +& ## +& # +
 ## +& ## +& # +
    +&    +&   +
&++++&&++++&&+++
]]

icon_action =
[[
3
 000000
.00FFFF00
+FFFFFF
.......  .......
...  . ++   ....
.. ++  ++ ++ ...
.. ++  ++ ++ . .
... ++ ++ ++  + 
... ++ ++ ++ ++ 
.  . +++++++ ++ 
 ++  ++++++++++ 
 +++ +++++++++ .
. ++++++++++++ .
.. +++++++++++ .
.. ++++++++++ ..
... +++++++++ ..
.... +++++++ ...
..... ++++++ ...
..... ++++++ ...
]]

icon_forge =
[[
11
 555555
.666666
+777777
@888888
#999999
$AAAAAA
%BBBBBB
&CCCCCC
*DDDDDD
=EEEEEE
-FFFFFF
*%&&&&*&*&&&&&&*
%$&=*=&%$$=-&-$%
&&%=&+.....%%&&&
&==&+@#@@@@ $*&&
&==@#%+++.$@.&*&
&*$@%#@++++%.@&&
&-$#%#@@@+.%+.&&
&=$$%$##@++&+.&&
&=$&%%@@@+%#.+=&
&=%**%$##$$+++=&
&-%***%&*@@+.$-&
&=&#=*%&&@@++%-&
&&&&#&%&&#++%*=&
&==-*#@%%+@&=&=&
&$***&*===*&&&$%
&%&%%%&&&&&%%%%*
]]

icon_status_colors =
[[
5
.0F0F0F
+FFFFFF00
@00BB00
#000000
$DD0000
]]

icon_textures = {
   ".......+",
   ".@.@.@.+",
   "..@.@..+",
   ".@.@.@.+",
   "..@.@..+",
   ".@.@.@.+",
   ".......+",
   "++++++++"
}

icon_lights = {
   ".......+",
   ".#####.+",
   ".####@.+",
   ".###@@.+",
   ".##@@@.+",
   ".#@@@@.+",
   ".......+",
   "++++++++"
}
icon_align = {
   ".......+",
   ".@@#@@.+",
   ".#####.+",
   ".@@#@@.+",
   ".#####.+",
   ".@@#@@.+",
   ".......+",
   "++++++++"
}

icon_empty = {
   "#######+",
   "#@@@@@#+",
   "#@@@@@#+",
   "#@@@@@#+",
   "#@@@@@#+",
   "#@@@@@#+",
   "#######+",
   "++++++++"
}

icon_transparent = {
   "$$$$$$$+",
   "$++$++$+",
   "$++$++$+",
   "$$$$$$$+",
   "$++$++$+",
   "$++$++$+",
   "$$$$$$$+",
   "++++++++"
}

