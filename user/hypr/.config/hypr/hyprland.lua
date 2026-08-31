-- Ported from hyprland.conf on 2026-06-08.
-- Hyprland 0.55+ Lua config.

-- re-assign hl to remove variable reference syntax wanrnings
hl = hl

----------------
-- Monitors
----------------

hl.monitor({ output = "DP-1", mode = "5120x1440@239.76", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x-1440", scale = 1 })
hl.monitor({ output = "DP-2", reserved = { top = 0, bottom = 10, left = 0, right = 0 } })

----------------
-- Programs
----------------

local terminal = "kitty"
local fileManager = "dolphin"
local menu = "rofi -show run"
local browser = "brave"
local mainMod = "SUPER"
local keyboardLayoutStatePath = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
	.. "/hyprland-keyboard-layout"

local function read_keyboard_layout()
	local state = io.open(keyboardLayoutStatePath, "r")
	if not state then
		return "us"
	end

	local layout = state:read("*l")
	state:close()
	return layout == "se" and "se" or "us"
end

local function write_keyboard_layout(layout)
	local state = io.open(keyboardLayoutStatePath, "w")
	if state then
		state:write(layout, "\n")
		state:close()
	end
end

local keyboardLayout = read_keyboard_layout()

----------------
-- Autostart
----------------

hl.on("hyprland.start", function()
	hl.exec_cmd(terminal)
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("swaync")
	hl.exec_cmd("wal -i ~/Pictures/wallpapers/aishot-1533.jpg")
end)

----------------
-- Environment
----------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_MENU_PREFIX", "arch-")
hl.env("AQ_NO_ATOMIC", "0")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

----------------
-- Layout: DP-1 workspace 3 zones
----------------

local triplewide_state = {
	right_id = nil,
	left_tree = nil,
	known = {},
	boxes = {},
	active_id = nil,
}

local function target_id(target)
	local window = target.window
	return window and tostring(window.stable_id) or tostring(target.index)
end

local function tree_contains(node, id)
	if not node then
		return false
	end
	if node.id then
		return tostring(node.id) == tostring(id)
	end
	return tree_contains(node.a, id) or tree_contains(node.b, id)
end

local function tree_toggle_split_for_active(node, active_id)
	if not node or node.id or not active_id then
		return false
	end

	if tree_contains(node.a, active_id) then
		if tree_toggle_split_for_active(node.a, active_id) then
			return true
		end
		node.split = node.split == "vertical" and "horizontal" or "vertical"
		return true
	end

	if tree_contains(node.b, active_id) then
		if tree_toggle_split_for_active(node.b, active_id) then
			return true
		end
		node.split = node.split == "vertical" and "horizontal" or "vertical"
		return true
	end

	return false
end

local function tree_leaf_count(node)
	if not node then
		return 0
	end
	if node.id then
		return 1
	end
	return tree_leaf_count(node.a) + tree_leaf_count(node.b)
end

local function tree_only_leaf_id(node)
	if not node then
		return nil
	end
	if node.id then
		return node.id
	end
	return tree_only_leaf_id(node.a) or tree_only_leaf_id(node.b)
end

local function split_for_longest_side(id, fallback_depth)
	local box = id and triplewide_state.boxes[id]
	if box then
		-- horizontal = left/right split, vertical = top/bottom split.
		-- Split along the longest side so 100x50 -> 50x50 + 50x50,
		-- and 60x100 -> 60x50 + 60x50.
		return box.w >= box.h and "horizontal" or "vertical"
	end

	-- First split before we have a measured box: left half is usually wide.
	return fallback_depth % 2 == 0 and "horizontal" or "vertical"
end

local function tree_insert_split_active(node, new_id, active_id, depth)
	if not node then
		return { id = new_id }
	end

	if node.id then
		if node.id == active_id or not active_id then
			return {
				split = split_for_longest_side(node.id, depth),
				ratio = 0.5,
				a = { id = node.id },
				b = { id = new_id },
			}
		end
		return node
	end

	if active_id and tree_contains(node.a, active_id) then
		node.a = tree_insert_split_active(node.a, new_id, active_id, depth + 1)
	elseif active_id and tree_contains(node.b, active_id) then
		node.b = tree_insert_split_active(node.b, new_id, active_id, depth + 1)
	else
		return {
			split = split_for_longest_side(nil, depth),
			ratio = 0.5,
			a = node,
			b = { id = new_id },
		}
	end

	return node
end

local function tree_prune(node, present)
	if not node then
		return nil
	end
	if node.id then
		return present[node.id] and node or nil
	end

	node.a = tree_prune(node.a, present)
	node.b = tree_prune(node.b, present)

	if node.a and node.b then
		return node
	end
	return node.a or node.b
end

local function place_tree(ctx, node, area, targets_by_id)
	if not node then
		return
	end
	if node.id then
		local target = targets_by_id[node.id]
		if target then
			target:place(area)
			triplewide_state.boxes[node.id] = area
		end
		return
	end

	local ratio = node.ratio or 0.5
	if node.split == "vertical" then
		place_tree(ctx, node.a, ctx:split(area, "top", ratio), targets_by_id)
		place_tree(ctx, node.b, ctx:split(area, "bottom", 1 - ratio), targets_by_id)
	else
		place_tree(ctx, node.a, ctx:split(area, "left", ratio), targets_by_id)
		place_tree(ctx, node.b, ctx:split(area, "right", 1 - ratio), targets_by_id)
	end
end

local function clamp_ratio(value)
	if value < 0.10 then
		return 0.10
	end
	if value > 0.90 then
		return 0.90
	end
	return value
end

local function tree_resize_active(ctx, node, active_id, dx, dy, area)
	if not node or node.id or not active_id then
		return false
	end

	local ratio = node.ratio or 0.5
	local active_in_a = tree_contains(node.a, active_id)
	local active_in_b = tree_contains(node.b, active_id)
	if not active_in_a and not active_in_b then
		return false
	end

	local a_area
	local b_area
	if node.split == "vertical" then
		a_area = ctx:split(area, "top", ratio)
		b_area = ctx:split(area, "bottom", 1 - ratio)
		if active_in_a and tree_resize_active(ctx, node.a, active_id, dx, dy, a_area) then
			return true
		end
		if active_in_b and tree_resize_active(ctx, node.b, active_id, dx, dy, b_area) then
			return true
		end

		if dy ~= 0 then
			-- Move the horizontal divider in screen direction regardless of
			-- which side the active tile is on. Down increases top ratio;
			-- up decreases it.
			local delta = dy / math.max(1, area.h)
			node.ratio = clamp_ratio(ratio + delta)
			return true
		end
	else
		a_area = ctx:split(area, "left", ratio)
		b_area = ctx:split(area, "right", 1 - ratio)
		if active_in_a and tree_resize_active(ctx, node.a, active_id, dx, dy, a_area) then
			return true
		end
		if active_in_b and tree_resize_active(ctx, node.b, active_id, dx, dy, b_area) then
			return true
		end

		if dx ~= 0 then
			-- Move the vertical divider in screen direction regardless of
			-- which side the active tile is on. Right increases left ratio;
			-- left decreases it.
			local delta = dx / math.max(1, area.w)
			node.ratio = clamp_ratio(ratio + delta)
			return true
		end
	end

	return false
end

local function tree_replace_id(node, old_id, new_id)
	if not node then
		return false
	end
	if node.id then
		if tostring(node.id) == tostring(old_id) then
			node.id = new_id
			return true
		end
		return false
	end
	return tree_replace_id(node.a, old_id, new_id) or tree_replace_id(node.b, old_id, new_id)
end
local function tree_remove_id(node, remove_id)
	if not node then
		return nil
	end
	if node.id then
		return tostring(node.id) == tostring(remove_id) and nil or node
	end

	node.a = tree_remove_id(node.a, remove_id)
	node.b = tree_remove_id(node.b, remove_id)

	if node.a and node.b then
		return node
	end
	return node.a or node.b
end

local function tree_collect_except(node, remove_id, out)
	if not node then
		return
	end
	if node.id then
		if tostring(node.id) ~= tostring(remove_id) then
			table.insert(out, node.id)
		end
		return
	end
	tree_collect_except(node.a, remove_id, out)
	tree_collect_except(node.b, remove_id, out)
end

local function tree_build_from_ids(ids, start_i, end_i, depth)
	if start_i > end_i then
		return nil
	end
	if start_i == end_i then
		return { id = ids[start_i] }
	end

	local mid = math.floor((start_i + end_i) / 2)
	return {
		split = depth % 2 == 0 and "horizontal" or "vertical",
		ratio = 0.5,
		a = tree_build_from_ids(ids, start_i, mid, depth + 1),
		b = tree_build_from_ids(ids, mid + 1, end_i, depth + 1),
	}
end

local function tree_rebuild_without(node, remove_id)
	local ids = {}
	tree_collect_except(node, remove_id, ids)
	return tree_build_from_ids(ids, 1, #ids, 0)
end

local function box_center(box)
	return box.x + box.w / 2, box.y + box.h / 2
end
local function id_at_cursor()
	local cursor = hl.get_cursor_pos()
	if not cursor then
		return nil
	end

	for id, box in pairs(triplewide_state.boxes) do
		if cursor.x >= box.x and cursor.x < box.x + box.w and cursor.y >= box.y and cursor.y < box.y + box.h then
			return id
		end
	end

	return nil
end

local function is_direction_match(ax, ay, bx, by, dir)
	if dir == "left" then
		return bx < ax and math.abs(by - ay) <= math.max(1, math.abs(bx - ax) * 2)
	end
	if dir == "right" then
		return bx > ax and math.abs(by - ay) <= math.max(1, math.abs(bx - ax) * 2)
	end
	if dir == "up" then
		return by < ay and math.abs(bx - ax) <= math.max(1, math.abs(by - ay) * 2)
	end
	if dir == "down" then
		return by > ay and math.abs(bx - ax) <= math.max(1, math.abs(by - ay) * 2)
	end
	return false
end

local function triplewide_swap_active(active_id, dir)
	local active_box = active_id and triplewide_state.boxes[active_id]
	if not active_box then
		return false
	end

	-- Empty right slot has priority over swapping with another left-side tile.
	-- If the active tile is on the right edge of the left tree and you swap
	-- right, move *that active tile* into the locked right slot.
	if dir == "right" and not triplewide_state.right_id then
		local active_right = active_box.x + active_box.w
		local max_right = active_right
		for _, box in pairs(triplewide_state.boxes) do
			local box_right = box.x + box.w
			if box_right > max_right then
				max_right = box_right
			end
		end

		if active_right >= max_right - 2 then
			triplewide_state.right_id = active_id
			triplewide_state.left_tree = tree_rebuild_without(triplewide_state.left_tree, active_id)
			return true
		end
	end

	local ax, ay = box_center(active_box)
	local best_id = nil
	local best_score = nil

	for id, box in pairs(triplewide_state.boxes) do
		if id ~= active_id then
			local bx, by = box_center(box)
			if is_direction_match(ax, ay, bx, by, dir) then
				local dx, dy = bx - ax, by - ay
				local score = dx * dx + dy * dy
				if not best_score or score < best_score then
					best_score = score
					best_id = id
				end
			end
		end
	end

	if not best_id then
		return false
	end

	local active_is_right = active_id == triplewide_state.right_id
	local best_is_right = best_id == triplewide_state.right_id

	if active_is_right then
		triplewide_state.right_id = best_id
		tree_replace_id(triplewide_state.left_tree, best_id, active_id)
	elseif best_is_right then
		triplewide_state.right_id = active_id
		tree_replace_id(triplewide_state.left_tree, active_id, best_id)
	else
		tree_replace_id(triplewide_state.left_tree, active_id, "__swap_tmp__")
		tree_replace_id(triplewide_state.left_tree, best_id, active_id)
		tree_replace_id(triplewide_state.left_tree, "__swap_tmp__", best_id)
	end

	return true
end

local is_workspace_3_active

local function custom_triplewide_swap(dir)
	if is_workspace_3_active() then
		local active = hl.get_active_window()
		local active_id = active and tostring(active.stable_id) or ""
		hl.dispatch(hl.dsp.layout("swap" .. dir .. " " .. active_id))
	else
		hl.dispatch(hl.dsp.window.swap({ direction = dir }))
	end
end

function is_workspace_3_active()
	local ws = hl.get_active_workspace()
	if ws and (ws.id == 3 or tostring(ws.id) == "3" or ws.name == "3") then
		return true
	end

	local mon = hl.get_active_monitor()
	ws = mon and mon.active_workspace
	return ws and (ws.id == 3 or tostring(ws.id) == "3" or ws.name == "3")
end

local function custom_triplewide_resize(ws3_dx, ws3_dy, normal_dx, normal_dy)
	if is_workspace_3_active() then
		hl.dispatch(hl.dsp.layout("resize " .. ws3_dx .. " " .. ws3_dy))
	else
		hl.dispatch(hl.dsp.window.resize({ x = normal_dx, y = normal_dy, relative = true }))
	end
end

local function custom_triplewide_move(dx, dy)
	if not is_workspace_3_active() then
		hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
	end
end

local function reapply_triplewide(ctx)
	triplewide_state.boxes = {}

	local targets_by_id = {}
	for _, target in ipairs(ctx.targets) do
		local id = target_id(target)
		targets_by_id[id] = target
	end

	local left_area = ctx:split(ctx.area, "left", 0.5)
	local right_area = ctx:split(ctx.area, "right", 0.5)

	local right_target = triplewide_state.right_id and targets_by_id[triplewide_state.right_id]
	if right_target then
		right_target:place(right_area)
		triplewide_state.boxes[triplewide_state.right_id] = right_area
	end

	place_tree(ctx, triplewide_state.left_tree, left_area, targets_by_id)
end

hl.layout.register("triplewide", {
	recalculate = function(ctx)
		local n = #ctx.targets
		if n == 0 then
			return
		end
		triplewide_state.boxes = {}

		-- DP-1 5120x1440:
		-- right half: one locked-size main tile, always 2560x1440
		-- left half: all other windows in a dwindle-ish tree
		local left_area = ctx:split(ctx.area, "left", 0.5)
		local right_area = ctx:split(ctx.area, "right", 0.5)

		local present = {}
		local targets_by_id = {}
		local new_ids = {}
		local active_left_id = nil

		for _, target in ipairs(ctx.targets) do
			local id = target_id(target)
			present[id] = true
			targets_by_id[id] = target
			if not triplewide_state.known[id] then
				table.insert(new_ids, id)
			end
			if target.window and target.window.active then
				triplewide_state.active_id = id
				if id ~= triplewide_state.right_id then
					active_left_id = id
				end
			end
		end

		-- Forget closed windows.
		for id, _ in pairs(triplewide_state.known) do
			if not present[id] then
				triplewide_state.known[id] = nil
			end
		end
		if triplewide_state.right_id and not present[triplewide_state.right_id] then
			triplewide_state.right_id = nil
		end
		triplewide_state.left_tree = tree_prune(triplewide_state.left_tree, present)

		if n == 1 then
			-- Preserve normal single-window behavior.
			ctx.targets[1]:place(ctx.area)
			triplewide_state.known[target_id(ctx.targets[1])] = true
			return
		end

		-- Pick/keep the locked right-half window.
		if not triplewide_state.right_id then
			local chosen = nil

			if #new_ids > 0 then
				-- If the main/right slot is empty, ANY newly-created window on
				-- workspace 3 fills that slot. Do not promote an existing tile.
				chosen = new_ids[#new_ids]
			elseif tree_leaf_count(triplewide_state.left_tree) == 1 then
				-- Right tile was closed and there is only one left-side tile: it
				-- can unambiguously expand/fill the right half.
				chosen = tree_only_leaf_id(triplewide_state.left_tree)
				triplewide_state.left_tree = nil
			end

			-- If there are multiple left-side leaves and no new window, leave
			-- the right half empty because choosing one would be ambiguous.
			triplewide_state.right_id = chosen
		end

		-- Put every non-right window into the left-half tree.
		for _, target in ipairs(ctx.targets) do
			local id = target_id(target)
			if id ~= triplewide_state.right_id and not tree_contains(triplewide_state.left_tree, id) then
				triplewide_state.left_tree = tree_insert_split_active(triplewide_state.left_tree, id, active_left_id, 0)
			end
			triplewide_state.known[id] = true
		end

		local right_target = targets_by_id[triplewide_state.right_id]
		if right_target then
			right_target:place(right_area)
			triplewide_state.boxes[triplewide_state.right_id] = right_area
		end
		place_tree(ctx, triplewide_state.left_tree, left_area, targets_by_id)
	end,

	layout_msg = function(ctx, msg)
		local command = msg:match("^(%S+)")

		local active_id = nil
		for _, target in ipairs(ctx.targets) do
			if target.window and target.window.active then
				active_id = target_id(target)
				break
			end
		end
		active_id = id_at_cursor() or active_id or triplewide_state.active_id

		if command == "togglesplit" then
			if active_id then
				tree_toggle_split_for_active(triplewide_state.left_tree, active_id)
				reapply_triplewide(ctx)
			end
			-- No-op for the locked right tile or unsplit left tile.
			return true
		end

		local dir, explicit_active_id = msg:match("^swap([^%s]+)%s*(%S*)")
		if dir == "left" or dir == "right" or dir == "up" or dir == "down" then
			if explicit_active_id and explicit_active_id ~= "" and triplewide_state.boxes[explicit_active_id] then
				active_id = explicit_active_id
			end
			if active_id then
				triplewide_swap_active(active_id, dir)
				reapply_triplewide(ctx)
			end
			return true
		end

		if command == "resize" then
			local dx, dy = msg:match("^resize%s+(-?%d+)%s+(-?%d+)")
			if active_id and active_id ~= triplewide_state.right_id and dx and dy then
				tree_resize_active(
					ctx,
					triplewide_state.left_tree,
					active_id,
					tonumber(dx),
					tonumber(dy),
					ctx:split(ctx.area, "left", 0.5)
				)
				reapply_triplewide(ctx)
			end
			return true
		end

		return "triplewide: expected togglesplit, swapleft, swapright, swapup, swapdown, or resize dx dy"
	end,
})

----------------
-- Look and feel
----------------

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 20,
		border_size = 3,
		resize_on_border = false,
		col = {
			active_border = "rgba(89b4faff)",
			inactive_border = "rgba(585b70cc)",
		},
		allow_tearing = false,
		layout = "dwindle",
		no_focus_fallback = true,
	},
	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 0.9,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},
	animations = {
		enabled = true,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
	binds = {
		window_direction_monitor_fallback = true,
	},
	cursor = {
		no_hardware_cursors = 0,
		hide_on_key_press = true,
	},
	input = {
		-- Expose one XKB group so applications cannot retain or select a
		-- window-specific layout. The explicit keybind replaces this map.
		kb_layout = keyboardLayout,
		kb_variant = "",
		kb_model = "pc104",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		force_no_accel = true,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

----------------
-- Input
----------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

----------------
-- Workspace rules
----------------

hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", layout = "lua:triplewide", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })

----------------
-- Binds
----------------

local function bounded_workspace(dir)
	return function()
		local mon = hl.get_active_monitor()
		if not mon or not mon.active_workspace then
			return
		end

		local ws = mon.active_workspace.id
		local target = nil

		if mon.name == "DP-1" then
			if dir == "next" then
				if ws == 1 then
					target = 2
				elseif ws == 2 then
					target = 3
				else
					target = 3
				end
			else
				if ws == 3 then
					target = 2
				elseif ws == 2 then
					target = 1
				else
					target = 1
				end
			end
		elseif mon.name == "DP-2" then
			if dir == "next" then
				if ws == 4 then
					target = 5
				else
					target = 5
				end
			else
				if ws == 5 then
					target = 4
				else
					target = 4
				end
			end
		end

		if target then
			hl.dispatch(hl.dsp.focus({ workspace = target, on_current_monitor = true }))
		end
	end
end

local function hypr_dispatch(expr)
	-- In Lua-config Hyprland, hyprctl dispatch expects a Lua dispatcher expression.
	return hl.dsp.exec_cmd("hyprctl dispatch '" .. expr .. "'")
end

local function bind_super_and_muhenkan(mods, key, dispatcher, opts)
	local prefix = mods == "" and "" or mods .. " + "
	local super_opts = {}
	if opts then
		for name, value in pairs(opts) do
			super_opts[name] = value
		end
	end
	super_opts.dont_inhibit = true

	hl.bind(mainMod .. " + " .. prefix .. key, dispatcher, super_opts)
	hl.bind(prefix .. "Muhenkan + " .. key, dispatcher, opts)
end

-- Keep the physical Super modifiers local while an application inhibits
-- shortcuts, without shadowing the Super chords below.
hl.bind("SUPER_L", function() end, { transparent = true, dont_inhibit = true })
hl.bind("SUPER_R", function() end, { transparent = true, dont_inhibit = true })

-- Muhenkan is a hardware prefix for the native multi-key binds below. Consume its
-- standalone event so applications do not receive the unused prefix press.
hl.bind("Muhenkan", function() end, { transparent = true })

bind_super_and_muhenkan("", "Q", hl.dsp.exec_cmd(terminal))
bind_super_and_muhenkan("", "C", hl.dsp.window.close())
bind_super_and_muhenkan(
	"",
	"Pause",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
bind_super_and_muhenkan("", "E", hl.dsp.exec_cmd(fileManager))
bind_super_and_muhenkan("", "V", hl.dsp.window.float({ action = "toggle" }))
bind_super_and_muhenkan("", "R", hl.dsp.exec_cmd(menu))
bind_super_and_muhenkan("", "P", hl.dsp.window.pseudo())
bind_super_and_muhenkan("", "END", hl.dsp.layout("togglesplit"))
bind_super_and_muhenkan("", "U", hl.dsp.layout("togglesplit"))
bind_super_and_muhenkan("ALT", "END", hl.dsp.layout("togglesplit"))
bind_super_and_muhenkan("CTRL", "END", hl.dsp.layout("togglesplit"))
bind_super_and_muhenkan("", "COMMA", hl.dsp.exec_cmd("hyprlock"))

-- HJKL tile management.
bind_super_and_muhenkan("", "H", hypr_dispatch([[hl.dsp.focus({direction="left"})]]))
bind_super_and_muhenkan("", "L", hypr_dispatch([[hl.dsp.focus({direction="right"})]]))
hl.bind(mainMod .. " + L", hypr_dispatch([[hl.dsp.focus({direction="right"})]]), { dont_inhibit = true })
hl.bind("Muhenkan + code:34", function() -- physical [ / å key (evdev 26 + XKB offset 8)
	keyboardLayout = keyboardLayout == "us" and "se" or "us"
	write_keyboard_layout(keyboardLayout)
	hl.config({ input = { kb_layout = keyboardLayout } })
end, { dont_inhibit = true })
bind_super_and_muhenkan("", "K", hypr_dispatch([[hl.dsp.focus({direction="up"})]]))
bind_super_and_muhenkan("", "J", hypr_dispatch([[hl.dsp.focus({direction="down"})]]))
bind_super_and_muhenkan("", "left", hypr_dispatch([[hl.dsp.focus({direction="left"})]]))
bind_super_and_muhenkan("", "right", hypr_dispatch([[hl.dsp.focus({direction="right"})]]))
bind_super_and_muhenkan("", "up", hypr_dispatch([[hl.dsp.focus({direction="up"})]]))
bind_super_and_muhenkan("", "down", hypr_dispatch([[hl.dsp.focus({direction="down"})]]))

bind_super_and_muhenkan("ALT", "H", function()
	custom_triplewide_swap("left")
end)
bind_super_and_muhenkan("ALT", "L", function()
	custom_triplewide_swap("right")
end)
bind_super_and_muhenkan("ALT", "K", function()
	custom_triplewide_swap("up")
end)
bind_super_and_muhenkan("ALT", "J", function()
	custom_triplewide_swap("down")
end)
bind_super_and_muhenkan("ALT", "left", function()
	custom_triplewide_swap("left")
end)
bind_super_and_muhenkan("ALT", "right", function()
	custom_triplewide_swap("right")
end)
bind_super_and_muhenkan("ALT", "up", function()
	custom_triplewide_swap("up")
end)
bind_super_and_muhenkan("ALT", "down", function()
	custom_triplewide_swap("down")
end)

bind_super_and_muhenkan("SHIFT", "H", function()
	custom_triplewide_resize(-60, 0, -60, 0)
end)
bind_super_and_muhenkan("SHIFT", "L", function()
	custom_triplewide_resize(60, 0, 60, 0)
end)
bind_super_and_muhenkan("SHIFT", "K", function()
	custom_triplewide_resize(0, -60, 0, -60)
end)
bind_super_and_muhenkan("SHIFT", "J", function()
	custom_triplewide_resize(0, 60, 0, 60)
end)

for i = 1, 5 do
	bind_super_and_muhenkan("", i, hl.dsp.focus({ workspace = i }))
	bind_super_and_muhenkan("SHIFT", i, hl.dsp.window.move({ workspace = i, silent = true }))
end

bind_super_and_muhenkan("CTRL", "L", bounded_workspace("next"))
bind_super_and_muhenkan("CTRL", "H", bounded_workspace("prev"))
bind_super_and_muhenkan("CTRL", "right", bounded_workspace("next"))
bind_super_and_muhenkan("CTRL", "left", bounded_workspace("prev"))
bind_super_and_muhenkan("CTRL", "down", hl.dsp.focus({ monitor = "DP-1" }))
bind_super_and_muhenkan("CTRL", "J", hl.dsp.focus({ monitor = "DP-1" }))
bind_super_and_muhenkan("CTRL", "up", hl.dsp.focus({ monitor = "DP-2" }))
bind_super_and_muhenkan("CTRL", "K", hl.dsp.focus({ monitor = "DP-2" }))

-- Fake minimization
-- bind_super_and_muhenkan("", "M", hl.dsp.window.move({ workspace = "special:hidden", silent = true }))
-- bind_super_and_muhenkan("", "N", hl.dsp.workspace.toggle_special("hidden"))
-- bind_super_and_muhenkan("", "TAB", hl.dsp.exec_cmd("kitty --class minimized-wins-popup --title minimized-wins-popup ~/.config/hypr/scripts/hypr-hidden-min.py --close-on-focus-lost"))

-- hidden workspace is used for fake minimization of windows.
-- It is not a real workspace, and it does not appear in the workspace list.
-- Windows moved to this workspace are hidden from view,
-- but they still exist and can be restored to their original workspace
-- bind_super_and_muhenkan("", "S", hl.dsp.workspace.toggle_special("magic"))
-- bind_super_and_muhenkan("SHIFT", "S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { dont_inhibit = true })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { dont_inhibit = true })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, dont_inhibit = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, dont_inhibit = true })

-- On the Swedish layout, Right Alt is AltGr, so these ALT mouse bindings are
-- effectively Left Alt only while that layout is active.
hl.bind("ALT + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("ALT + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Native Wayland region capture: select with slurp, capture with grim, then
-- save the PNG and copy it to the clipboard.
hl.bind(
	"Print",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/region-screenshot.sh"),
	{ dont_inhibit = true }
)

-- Space Marine 2's former 16:9/32:9 window-size toggle is disabled while
-- the game uses a fixed, supported 3440x1440 Gamescope display for online play.

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

bind_super_and_muhenkan("", "B", hl.dsp.exec_cmd(browser))

----------------
-- Window rules
----------------

hl.window_rule({
	name = "rocksmith-2014-center",
	match = { initial_class = "^(steam_app_221680)$" },
	center = true,
})

hl.window_rule({
	name = "space-marine-2-windowed-toggle",
	match = {
		initial_class = "^(steam_app_2183900)$",
		initial_title = "^Warhammer 40,000: Space Marine 2$",
	},
	workspace = "2",
	float = true,
	center = true,
	border_size = 0,
	rounding = 0,
	no_shadow = true,
	no_anim = true,
})

hl.window_rule({
	name = "space-idle-render-unfocused",
	match = { initial_class = "^(SpaceIdle)$", xwayland = true },
	render_unfocused = true,
})

hl.window_rule({ match = { class = "^(minimized-wins-popup)$" }, float = true })
hl.window_rule({ match = { class = "^(minimized-wins-popup)$" }, center = true })
hl.window_rule({ match = { class = "^(minimized-wins-popup)$" }, size = "530 300" })

hl.window_rule({
	name = "unreal-editor-workspace",
	match = { class = "^(UnrealEditor)$" },
	workspace = "3",
})
hl.window_rule({
	name = "unreal-editor-no-effects",
	match = { class = "^(UnrealEditor)$" },
	no_blur = true,
	no_shadow = true,
})

-- Unreal Engine XWayland popup/drag workaround.
-- Untitled Unreal popups are used for drag/drop and transient menus; letting
-- them take initial focus can cancel drags or put the editor in a bad focus
-- state under Hyprland/XWayland.
hl.window_rule({
	name = "unreal-untitled-no-initial-focus",
	match = { class = "^(UnrealEditor)$", title = "^%w*$" },
	no_initial_focus = true,
})
hl.window_rule({
	name = "unreal-untitled-suppress-activate",
	match = { class = "^(UnrealEditor)$", title = "^%w*$" },
	suppress_event = "activate",
})
hl.window_rule({
	name = "unreal-untitled-no-anim",
	match = { class = "^(UnrealEditor)$", title = "^%w*$" },
	no_anim = true,
})

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

hl.window_rule({ match = { class = "^(wiremix-popup)$" }, float = true })
hl.window_rule({ match = { class = "^(wiremix-popup)$" }, size = "900 520" })
hl.window_rule({ match = { class = "^(wiremix-popup)$" }, move = "20 835" })
