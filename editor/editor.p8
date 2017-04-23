pico-8 cartridge // http://www.pico-8.com
version 9
__lua__
-- scumm-8 editor (pus)
-- by paul nicholas

-- debugging
show_debuginfo = true
show_collision = false
--show_pathfinding = true
show_perfinfo = true
enable_mouse = true
d = printh


-- global vars
rooms = {}
objects = {}
actors = {}
stage_top = 8 --16
cam_x = 100--0
draw_zplanes = {}		-- table of tables for each of the (8) zplanes for drawing depth
cursor_x, cursor_y, cursor_tmr, cursor_colpos = 63.5, 63.5, 0, 1
cursor_cols = {7,12,13,13,12,7}
curr_selection = nil		-- currently selected object/actor (or room, if nil)
curr_selection_class = nil
prop_page_num = 0

-- "dark blue" gui theme
gui_bg1 = 1
gui_bg2 = 5
gui_bg3 = 6
gui_fg1 = 12
gui_fg2 = 13
gui_fg3 = 7


-- list of properties (room/object/actor)
-- types:
--   1 = number
--   2 = string
--   3 = bool
--   4 = decimal (0..1)

--  10 = state ref
--  11 = states list (or numbers)
--  12 = classes list 
--  13 = color picker
--  14 = color replace list (using pairs of color pickers)
--  15 = 

--  30 = use position (pos preset or specific pos)
--  31 = use/face dir

--  40 = single sprites (directional)
--  41 = sprite anim sequence
--  

--  50 = object ref

prop_definitions = {
	-- shared props (room/object/actor)
	{"trans_col", "trans col", 13, {"class_room","class_object","class_actor"} },
	{"col_replace", "col swap", 14, {"class_room","class_object","class_actor"} },
	{"lighting", "lighting", 4, {"class_room","class_object","class_actor"} },

	-- object/actor props
	{"name", "name", 2, {"class_object","class_actor"} },
	{"x", "x", 1, {"class_object","class_actor"} },
	{"y", "y", 1, {"class_object","class_actor"} },
	{"z", "z", 1, {"class_object","class_actor"} },
	{"w", "w", 1, {"class_object","class_actor"} },
	{"h", "h", 1, {"class_object","class_actor"} },
	{"state", "state", 10, {"class_object","class_actor"} },
	{"states", "states", 11, {"class_object","class_actor"} },
	{"classes", "classes", 12, {"class_object","class_actor"} },
	{"use_pos", "use pos", 30, {"class_object","class_actor"} },
	{"use_dir", "use dir", 31, {"class_object","class_actor"} },
	{"use_with", "use with", 3, {"class_object","class_actor"} },
	{"repeat_x", "repeat_x", 1, {"class_object","class_actor"} },
	{"flip_x", "flip x", 3, {"class_object","class_actor"} },

	-- object props
	{"dependent_on", "depends on", 50, {"class_object"} },
	{"dependent_on_state", "state req", 11, {"class_object"} },

	-- room-only props
	{"map", "map", type, prop_room},

	-- actor-only props
	{"idle", "idle frame", 40, {"class_actor"} },
	{"talk", "talk frame", 40, {"class_actor"} },
	{"walk_anim_side", "walk anim(side)", 41, {"class_actor"} },
	{"walk_anim_front", "walk anim(front)", 41, {"class_actor"} },
	{"walk_anim_back", "walk anim(back)", 41, {"class_actor"} },
	{"col", "talk col", 13, {"class_actor"} },
	{"walk_speed", "walk speed", 1, {"class_actor"} },
	{"frame_delay", "anim speed", 1, {"class_actor"} },
	{"face_dir", "start dir", 31, {"class_actor"} },

}


function _init()
  base_cart_name = "game_base"
  disk_cart_name = "game_disk"
  num_extra_disks = 0    
  is_dirty = false  -- has been modified since last "save"?

	room_index = 2--1


  -- packed game data (rooms/objects/actors)
  data = [[
			id=1/map={0,16}/objects={}
      id=2/map={0,24,31,31}/objects={30,31,32,33,34,35}
      id=3/map={32,24,55,31}/col_replace={5,2}/objects={}
      id=4/map={56,24,79,31}/trans_col=10/col_replace={7,4}/lighting=0.25/objects={}
      id=5/map={80,24,103,31}/objects={}
      id=6/map={104,24,127,31}/objects={}
      id=7/map={32,16,55,31}/objects={}
      id=8/map={64,16}/objects={}
			|
			id=30/x=144/y=40/classes={class_untouchable}
			id=31/state=state_here/x=80/y=24/w=1/h=2/state_here=47/trans_col=8/repeat_x=8/classes={class_untouchable}
			id=32/state=state_here/x=176/y=24/w=1/h=2/state_here=47/trans_col=8/repeat_x=8/classes={class_untouchable}
			id=33/name=front door/state=state_closed/x=152/y=8/w=1/h=3/state_closed=78/flip_x=true/classes={class_openable,class_door}/use_dir=face_back
			id=34/name=bucket/state=state_open/x=208/y=48/w=1/h=1/state_closed=143/state_open=159/trans_col=15/use_with=true/classes={class_pickupable}
			|
			id=1000/name=humanoid/w=1/h=4/idle={193,197,199,197}/talk={218,219,220,219}/walk_anim_side={196,197,198,197}/walk_anim_front={194,193,195,193}/walk_anim_back={200,199,201,199}/col=12/trans_col=11/walk_speed=0.6/frame_delay=5/classes={class_actor}/face_dir=face_front
			id=1001/name=purpletentacle/x=140/y=52/w=1/h=3/idle={154,154,154,154}/talk={171,171,171,171}/col=11/trans_col=15/walk_speed=0.4/frame_delay=5/classes={class_actor,class_talkable}/face_dir=face_front/use_pos=pos_left
		]]

  -- unpack data to it's relevent target(s)
  printh("------------------------------------")
  explode_data(data)
  set_data_defaults()

		-- use mouse input?
	if enable_mouse then poke(0x5f2d, 1) end

  -- load gfx + map from current "disk" (e.g. base cart)
	reload(0,0,0x1800, base_cart_name..".p8") -- first 3 gfx pages
  reload(0x2000,0x2000,0x1000, base_cart_name..".p8") -- map + props

  --reload(0,0,0x3000, base_cart_name..".p8")
end

function _draw()
	draw_editor()
end

function _update60()

	update_room()

	input_control()

  room_index = mid(1, room_index, #rooms)

  room_curr = rooms[room_index]

	-- default first selection to current room
	if not curr_selection then
		curr_selection = room_curr
		curr_selection_class = "class_room"
	end

  cam_x = mid(0, cam_x, (room_curr.map_w*8)-127 -1)

	draw_cursor()
end

-- ===========================================================================
-- update related
--

function update_room()
	-- check for current room
	if not room_curr then
		return
	end

	-- reset hover collisions
	hover_curr_selection = nil

 	-- reset zplane info
	reset_zplanes()

	-- check room/object collisions
	for obj in all(room_curr.objects) do

		--printh("obj:"..obj.id)

		-- capture bounds
		-- if not has_flag(obj.classes, "class_untouchable") then
		recalc_bounds(obj, obj.w*8, obj.h*8, cam_x, cam_y)
		-- end

		--d("obj-z:"..type(obj.z))
		
		-- mouse over?
		if iscursorcolliding(obj) then

			-- if highest (or first) object in hover "stack"
			if not hover_curr_selection
			 or	(not obj.z and hover_curr_selection.z and hover_curr_selection.z < 0) 
			 or	(obj.z and hover_curr_selection.z and obj.z > hover_curr_selection.z) 
			then
				hover_curr_selection = obj
				hover_curr_selection_class = "class_object"
			end
		end
		-- recalc z-plane
		recalc_zplane(obj)
	end

end

function reset_zplanes()
	draw_zplanes = {}
	for x = -64, 64 do
		draw_zplanes[x] = {}
	end
end

function recalc_zplane(obj)
	-- calculate the correct z-plane
	-- based on x,y pos + elevation
	ypos = -1
	if obj.offset_y then
		ypos = obj.y
	else
		ypos = obj.y + (obj.h*8)
	end
	zplane = flr(ypos) --  - stage_top)
	--d("object_zcal obj:"..obj.id.." = "..zplane.."(h="..obj.h..")")

	if obj.z then
		zplane = obj.z
	end

	add(draw_zplanes[zplane],obj)
end

function iscursorcolliding(obj)
	-- check params / not in cutscene
	if not obj.bounds then 
	 return false 
	end
	
	bounds = obj.bounds
	if (cursor_x + bounds.cam_off_x > bounds.x1 or cursor_x + bounds.cam_off_x < bounds.x) 
	 or (cursor_y > bounds.y1 or cursor_y < bounds.y) then
		return false
	else
		return true
	end
end

-- handle button inputs
function input_control()	

	-- check for cutscene "skip/override"
	-- (or that we have an actor to control!)
	if cutscene_curr then
		if btnp(4) and btnp(5) and cutscene_curr.override then 
			-- skip cutscene!
			cutscene_curr.thread = cocreate(cutscene_curr.override)
			cutscene_curr.override = nil
			--if (enable_mouse) then ismouseclicked = true end
			return
		end
		-- either way - don't allow other user actions!
		return
	end

	-- 

  -- handle player input
  if btnp(2) then
    room_index += 1
		curr_selection = nil
  end
  if btnp(3) then
    room_index -= 1
		curr_selection = nil
  end
  if btn(1) then
    cam_x += 1
  end
  if btn(0) then
    cam_x -= 1
  end
	-- if btn(0) then cursor_x -= 1 end
	-- if btn(1) then cursor_x += 1 end
	-- if btn(2) then cursor_y -= 1 end
	-- if btn(3) then cursor_y += 1 end

	-- if btnp(4) then input_button_pressed(1) end
	-- if btnp(5) then input_button_pressed(2) end

	-- only update position if mouse moved
	if enable_mouse then	
		mouse_x,mouse_y = stat(32)-1, stat(33)-1
		if mouse_x != last_mouse_x then cursor_x = mouse_x end	-- mouse xpos
		if mouse_y!= last_mouse_y then cursor_y = mouse_y end  -- mouse ypos
		-- don't repeat action if same press/click
		if stat(34) > 0 then
			if not ismouseclicked then
				input_button_pressed(stat(34))
				ismouseclicked = true
			end
		else
			ismouseclicked = false
		end
		-- store for comparison next cycle
		last_mouse_x = mouse_x
		last_mouse_y = mouse_y
	end

	-- keep cursor within screen
	cursor_x = mid(0, cursor_x, 127)
	cursor_y = mid(0, cursor_y, 127)
end

-- 1 = z/lmb, 2 = x/rmb, (4=middle)
function input_button_pressed(button_index)	

	-- todo: check for modal dialog input first

	-- check room-level interaction


	if hover_curr_cmd then


	elseif hover_curr_selection then
		-- select object
		curr_selection = hover_curr_selection
		curr_selection_class = hover_curr_selection_class
	
	
	
	else
		-- nothing clicked (so default to room selected)
		curr_selection = room_curr
		curr_selection_class = "class_room"
	end
end



-- ===========================================================================
-- draw related
--
function draw_editor()
	cls()

  -- reposition camera (account for shake, if active)
	camera(cam_x,0)

	-- clip room bounds (also used for "iris" transition)
	clip(0, stage_top, 128, 64)
    
	-- draw room (bg + objects + actors)
	draw_room()

	-- reset camera and clip bounds for "static" content (ui, etc.)
	camera(0,0)
	clip()

	draw_gui()

	draw_cursor()
end

function draw_room()
	-- todo: factor in diff drawing modes?

	 -- check for current room
	if not room_curr then
		print("-error-  no current room set",5+cam_x,5+stage_top,8,0)
		return
	end


	-- set room background col (or black by default)
	rectfill(0, stage_top, 127, stage_top+64, room_curr.bg_col or 0)


	-- draw each zplane, from back to front
	for z = -64,64 do

		-- draw bg layer?
		if z == 0 then			
			-- replace colors?
			replace_colors(room_curr)

			if room_curr.trans_col then
				set_trans_col(room_curr.trans_col, true)
				-- palt(0, false)
				-- palt(room_curr.trans_col, true)
			end

  		map(room_curr.map[1], room_curr.map[2], 0, stage_top, room_curr.map_w, 8)
			--map(room_curr.map[1], room_curr.map[2], 0, stage_top, room_curr.map_w, room_curr.map_h)
			
			--reset palette
			pal()		


					-- ===============================================================
					-- debug walkable areas
					
					-- if show_pathfinding then
					-- 	actor_cell_pos = getcellpos(selected_actor)

					-- 	celx = flr((cursor_x + cam_x + 0) /8) + room_curr.map[1]
					-- 	cely = flr((cursor_y - stage_top + 0) /8 ) + room_curr.map[2]
					-- 	target_cell_pos = { celx, cely }

					-- 	path = find_path(actor_cell_pos, target_cell_pos)

					-- 	-- finally, add our destination to list
					-- 	click_cell = getcellpos({x=(cursor_x + cam_x), y=(cursor_y - stage_top)})
					-- 	if is_cell_walkable(click_cell[1], click_cell[2]) then
					-- 	--if (#path>0) then
					-- 		add(path, click_cell)
					-- 	end

					-- 	for p in all(path) do
					-- 		--d("  > "..p[1]..","..p[2])
					-- 		rect(
					-- 			(p[1]-room_curr.map[1])*8, 
					-- 			stage_top+(p[2]-room_curr.map[2])*8, 
					-- 			(p[1]-room_curr.map[1])*8+7, 
					-- 			stage_top+(p[2]-room_curr.map[2])*8+7, 11)
					-- 	end
					-- end

		else
			-- draw other layers
			zplane = draw_zplanes[z]
		
			-- draw all objs/actors in current zplane
			for obj in all(zplane) do
				-- object or actor?
					--d("object_zplane:"..obj.id)

				if not has_flag(obj.classes, "class_actor") then
					-- object
					-- if obj.states	  -- object has a state?
				  --   or (obj.state
					--    and obj[obj.state]
					--    and obj[obj.state] > 0)
					--  and (not obj.dependent_on 			-- object has a valid dependent state?
					-- 	or obj.dependent_on.state == obj.dependent_on_state)
					--  and not obj.owner   						-- object is not "owned"
					--  or obj.draw
					-- then
						-- something to draw
						object_draw(obj)
					--end
				else
					-- actor
					if obj.in_room == room_curr then
						actor_draw(obj)
					end
				end

				if obj.bounds then
					if curr_selection == obj then
						rect(obj.bounds.x-1, obj.bounds.y-1, obj.bounds.x1+1, obj.bounds.y1+1, cursor_cols[cursor_colpos]) 
					elseif hover_curr_selection == obj
						or show_collision 
					then
						rect(obj.bounds.x-1, obj.bounds.y-1, obj.bounds.x1+1, obj.bounds.y1+1, 8)
						--rect(obj.bounds.x-2, obj.bounds.y-2, obj.bounds.x1+2, obj.bounds.y1+2, 2)
					end
				end	
			end
		end		
	end
end

function draw_gui()
	-- header bar
	rectfill(0,0,127,7,gui_bg1)
	pal(5,12)
	spr(192,3,1)
	spr(193,12,1)
	spr(194,22,1)
	--
	pal(5,7)
	spr(212,101,1)
	pal(5,12)
	spr(229,110,1)
	spr(230,119,1)
	
	pal()
	
	-- properties (bar)
	rectfill(0,72,127,82,gui_bg2)
	if curr_selection then
		print(
			sub(curr_selection_class,7)..":"..pad_3(curr_selection.id)
			,10,74,gui_fg3)
	end

	spr(204,96,74)
	spr(221,104,74)
	spr(222,112,74)
	spr(223,120,74)

	-- properties (section)
	rectfill(0,82,127,119,gui_fg3)


	-- find all properties for selected object (or room, if no obj/actor selected)
	local xoff=0
	local yoff=0
	local start_pos = prop_page_num * 12 +1
	for i = start_pos, min(start_pos+12-1, #prop_definitions) do
		d("i="..i)
	--for p in all(prop_definitions) do
		local prop = prop_definitions[i]
		if curr_selection 
		 and has_flag(prop[4], curr_selection_class)
		then
			print(prop[2], 3+xoff, 83+yoff, gui_bg2)
			yoff += 6
			if yoff > 30 then 
				yoff = 0
				xoff += 60 
			end
		end
	end

	-- status bar
	rectfill(0,119,127,127,gui_bg1)
	print("x:"..pad_3(cursor_x+cam_x).." y:"..pad_3(cursor_y-stage_top), 
		3,121, gui_bg2) 

	print("cpu:"..flr(100*stat(1)).."%", 
		66, 121, gui_bg2) 
	print("mem:"..flr(stat(0)/1024*100).."%", 
		98, 121, gui_bg2)

end


function draw_cursor()
	col = cursor_cols[cursor_colpos]
	-- switch sprite color accordingly

	line(cursor_x-4, cursor_y,cursor_x-1, cursor_y, col)
	line(cursor_x+1, cursor_y,cursor_x+4, cursor_y, col)
	line(cursor_x, cursor_y-4,cursor_x, cursor_y-1, col)
	line(cursor_x, cursor_y+1,cursor_x, cursor_y+4, col)

	--pset(cursor_x, cursor_y, 8)
	-- pal(7,col)
	-- spr(1, cursor_x-4, cursor_y-3, 1, 1, 0)
	-- pal() --reset palette

	cursor_tmr += 1
	if cursor_tmr > 14 then
		--reset timer
		cursor_tmr = 1
		-- move to next color?
		cursor_colpos += 1
		if cursor_colpos > #cursor_cols then cursor_colpos = 1 end
	end
end

function replace_colors(obj)
	-- replace colors (where defined)
	if obj.col_replace then
		c = obj.col_replace
		--for c in all(obj.col_replace) do
			pal(c[1], c[2])
		--end
	end
	-- also apply brightness (default to room-level, if not set)
	if obj.lighting then
		_fadepal(obj.lighting)
	elseif obj.in_room 
	 and obj.in_room.lighting then
		_fadepal(obj.in_room.lighting)
	end
end


function object_draw(obj)
	-- replace colors?
	replace_colors(obj)

	--d("object_draw:"..obj.id)

	-- check for custom draw
	if not obj.state then
		--obj.draw(obj)
		palt(0,false)
		spr(217, obj.x, obj.y + stage_top)
		pal()
		return
	else
		-- allow for repeating
		rx=1
		if obj.repeat_x then rx = obj.repeat_x end
		for h = 0, rx-1 do
			-- draw object (in its state!)
			local obj_spr = 0
			if obj.states then
				obj_spr = obj.states[obj.state]
			else
				obj_spr = obj[obj.state]
			end
			sprdraw(obj_spr, obj.x+(h*(obj.w*8)), obj.y, obj.w, obj.h, obj.trans_col, obj.flip_x)
		end
	end

	--reset palette
	pal() 
end

-- draw actor(s)
function actor_draw(actor)

	dirnum = face_dir_vals[actor.face_dir]

	if actor.moving == 1
	 and actor.walk_anim 
	then
		actor.tmr += 1
		if actor.tmr > actor.frame_delay then
			actor.tmr = 1
			actor.anim_pos += 1
			if actor.anim_pos > #actor.walk_anim then actor.anim_pos=1 end
		end
		-- choose walk anim frame
		sprnum = actor.walk_anim[actor.anim_pos]	
	else

		-- idle
		sprnum = actor.idle[dirnum]
	end

	-- replace colors?
	replace_colors(actor)

	sprdraw(sprnum, actor.offset_x, actor.offset_y, 
		actor.w , actor.h, actor.trans_col, 
		actor.flip, false)
	
	-- talking overlay
	if talking_actor 
	 and talking_actor == actor 
	 and talking_actor.talk
	then
			if actor.talk_tmr < 7 then
				sprnum = actor.talk[dirnum]
				sprdraw(sprnum, actor.offset_x, actor.offset_y +8, 1, 1, 
					actor.trans_col, actor.flip, false)
			end
			actor.talk_tmr += 1	
			if actor.talk_tmr > 14 then actor.talk_tmr = 1 end
	end

	--reset palette
	pal()
end

function draw_ui()
	-- todo: factor in diff drawing modes?
end

function sprdraw(n, x, y, w, h, transcol, flip_x, flip_y)
	-- switch transparency
	set_trans_col(transcol, true)

	-- draw sprite
	spr(n, x, stage_top + y, w, h, flip_x, flip_y)

	--pal() -- don't do, affects lighting!
end

function set_trans_col(transcol, enabled)
	-- set transparency for specific col
	palt(0, false)
	palt(transcol, true)
	
	-- set status of default transparency
	if transcol and transcol > 0 then
		palt(0, false)
	end
end


function _fadepal(perc)
 if perc then perc = 1-perc end
 local p=flr(mid(0,perc,1)*100)
 local dpal={0,1,1, 2,1,13,6,
          4,4,9,3, 13,1,13,14}
 for j=1,15 do
  col = j
  kmax=(p+(j*1.46))/22
  for k=1,kmax do
   col=dpal[col]
  end
  pal(j,col)
 end
end



-- ===========================================================================
-- data related
--

function has_flag(obj, value)
	for f in all(obj) do
	 if f == value then 
	 	return true 
	 end
	end
  --if band(obj, value) != 0 then return true end
  return false
end

function recalc_bounds(obj, w, h, cam_off_x, cam_off_y)
  x = obj.x
	y = obj.y
	-- offset for actors?
	if has_flag(obj.classes, "class_actor") then
		obj.offset_x = x - (obj.w *8) /2
		obj.offset_y = y - (obj.h *8) +1		
		x = obj.offset_x
		y = obj.offset_y
	end

	-- adjust bounds for repeat-drawn sprites
	if obj.repeat_x then 
		w *= obj.repeat_x 
	end

	obj.bounds = {
		x = x,
		y = y + stage_top,
		x1 = x + w -1,
		y1 = y + h + stage_top -1,
		cam_off_x = cam_off_x,
		cam_off_y = cam_off_y
	}
end


-- ===========================================================================
-- pack/unpack related
--

function set_data_defaults()
  
  -- init rooms
	for room in all(rooms) do		
		if (#room.map > 2) then
			room.map_w = room.map[3] - room.map[1] + 1
			room.map_h = room.map[4] - room.map[2] + 1
		else
			room.map_w = 16
			room.map_h = 8
		end

		-- init objects (in room)
		local obj_list = {}
		for obj_id in all(room.objects) do
			printh("obj id2: "..obj_id)
			obj = objects[obj_id]
			if obj then
				obj.in_room = room
				obj.h = obj.h or 1
				obj.w = obj.w or 1
				-- if obj.repeat_x  then
				-- 	d("repeat:"..obj.repeat_x.." --- obj.w:"..obj.w)
				-- end
				add(obj_list, obj)
			end
		end
		-- now replace room.objectids with .objects
		room.objects = obj_list
	end

	-- init actors with defaults
	-- for ka,actor in pairs(actors) do
	-- 	explode_data(actor)
	-- 	actor.moving = 2 		-- 0=stopped, 1=walking, 2=arrived
	-- 	actor.tmr = 1 		  -- internal timer for managing animation
	-- 	actor.talk_tmr = 1
	-- 	actor.anim_pos = 1 	-- used to track anim pos
	-- 	actor.inventory = {
	-- 		-- obj_switch_player,
	-- 		-- obj_switch_tent
	-- 	}
	-- 	actor.inv_pos = 0 	-- pointer to the row to start displaying from
	-- end
end


function explode_data(data)
  local areas=split(data, "|")
  
  -- unpack rooms + data
  local room_data = areas[1]
	local lines=split(room_data, "\n")
	for l in all(lines) do
    room = {}
		--d("curr line = ["..l.."]")
    local properties=split(l, "/")
		local id = 0
    for prop in all(properties) do
      --printh("curr prop = ["..prop.."]")
      local pairs=split(prop, "=")
      if #pairs==2 then
				if pairs[1] == "id" then
					id = autotype(pairs[2])
				end
				room[pairs[1]] = autotype(pairs[2])
      else
        printh("invalid data line")
      end
    end
		-- only add if something to add
		if #properties > 0 
		 and id > 0 then
			rooms[id] = room
    	--add(rooms, room)
		end
		--if (room.objects) printh("obj count:"..#room.objects)
	end

	-- unpack objects + data
	local obj_data = areas[2]
	local lines=split(obj_data, "\n")
	for l in all(lines) do
    obj = {}
    local properties=split(l, "/")
		local id = 0
    for prop in all(properties) do
      local pairs=split(prop, "=")
      -- now set actual values
      if #pairs==2 then
				if pairs[1] == "id" then
					id = autotype(pairs[2])
				end
				obj[pairs[1]] = autotype(pairs[2])
      else
        printh("invalid data line")
      end
    end
		-- only add if something to add
		if #properties > 0 
		 and id > 0 then
			objects[id] = obj
    	--add(objects, room)
		end
	end
	--printh("objects:"..#objects)

	-- unpack actors + data
	local actor_data = areas[3]
	local lines=split(actor_data, "\n")
	for l in all(lines) do
    actor = {}
    local properties=split(l, "/")
		local id = 0
    for prop in all(properties) do
			--printh("curr prop = ["..prop.."]")
      local pairs=split(prop, "=")
      -- now set actual values
      if #pairs==2 then
				if pairs[1] == "id" then
					id = autotype(pairs[2])
				end
				actor[pairs[1]] = autotype(pairs[2])
      else
        printh("invalid data line")
      end
    end
		-- only add if something to add
		if #properties > 0 
		 and id > 0 then
			actors[id] = actor
    	--add(actors, actor)
		end
	end

	--printh("actors:"..#actors)
end

function split(s, delimiter)
	local retval = {}
	local start_pos = 0
	local last_char_pos = 0

	for i=1,#s do
		local curr_letter = sub(s,i,i)
		if curr_letter == delimiter then
			add(retval, sub(s,start_pos,last_char_pos))
			start_pos = 0
			last_char_pos = 0

		elseif curr_letter != " "
		 and curr_letter != "\t" then
			-- curr letter is useful
			last_char_pos = i
			if start_pos == 0 then start_pos = i end
		end
	end
	-- add remaining content?
	if start_pos + last_char_pos > 0 then 	
		add(retval, sub(s,start_pos,last_char_pos))
	end
	return retval
end

function autotype(str_value)
	local first_letter = sub(str_value,1,1)
	local retval = nil

	if str_value == "true" then
		retval = true
	elseif str_value == "false" then
		retval = false
	elseif is_num_char(first_letter) then
		-- must be number
		if first_letter == "-" then
			retval = sub(str_value,2,#str_value) * -1
		else
			retval = str_value + 0
		end
	elseif first_letter == "{" then
		-- array - so split it
		local temp = sub(str_value,2,#str_value-1)
		retval = split(temp, ",")
		retarray = {}
		for val in all(retval) do
			val = autotype(val)
			add(retarray, val)
		end
		retval = retarray
	else --if first_letter == "\"" then
		-- string - so do nothing
		retval = str_value
	end
	return retval
end

function is_num_char(c)
	for d=1,13 do
		if c==sub("0123456789.-+",d,d) then
			return true
		end
	end
end

function pad_3(number)
	local strnum=""..flr(number)
	local z="000"
	return sub(z,#strnum+1)..strnum
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055000055505000005000000000000000000000000000000055000005500000055500000800000000000000000000007777700077777000777770007777700
505000000555055000555000000000000055500055500000005555000055000050555050097f0000000000000000000077ccc77077cc777077ccc77077ccc770
550055500555555005555500000000000555550050555555005555000005000050050050a777e000000000000000000077c7c770777c77707777c770777cc770
5550055005000050000500000000000055555550555005500005500005555500055555000b7d0000000000000000000077c7c770777c777077c777707777c770
00005050050000505000005000000000050505000000055000555500005550000055500000c00000000000000000000077ccc77077ccc77077ccc77077ccc770
00550000050000505555555000000000050555000000000005555550005550000055500000000000000000000000000077777770777777707777777077777770
00000000000000000000000000000000000000000000000000000000005050000050500000000000000000000000000077777770777777707777777077777770
000000000000000000000000000000000000000000000000000000000050500005505500000000000000000000000000ccccccc0ccccccc0ccccccc0ccccccc0
00000000000500000000000000000000005550000000000000000000005500000000000082828282000000000000000000000000000000000000000000000000
00000000055555000000000000000000055555000055500000555000005500000000000020000008000000000000000001111100011111000111110001111100
00000000005550000000000000000000555555500555050000555000000500000000000080800802000000000000000011ccc11011cc111011ccc11011ccc110
00000000000500000000000000000000055505000555550005555500055555000000000020088008000000000000000011c1c110111c11101111c110111cc110
00000000500000500000000000000000050555000555550000555000005550000000000080088002000000000000000011c1c110111c111011c111101111c110
00000000555555500000000000000000050555000055500000505000005550000000000020800808000000000000000011ccc11011ccc11011ccc11011ccc110
00000000000000000000000000000000000000000000000000000000005050000000000080000002000000000000000011111110111111101111111011111110
00000000000000000000000000000000000000000000000000000000005050000000000028282828000000000000000011111110111111101111111011111110
00000000000000000000000000000000000000000005500000555000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055050000555000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000555505000050000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000555555005555500000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055550000555000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000005500000505000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

