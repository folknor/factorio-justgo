
local acceptedTypes = {
	car = true,
	locomotive = true,
}
local filterCache = {}
local sPickupKey = "folk-justgo-pickup"
local pickup = setmetatable({}, {
	__index = function(self, id)
		local v = settings.get_player_settings(game.players[id])[sPickupKey].value
		rawset(self, id, v)
		return v
	end
})
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	if not event or not event.setting then return end
	if event.setting == sPickupKey then
		pickup[event.player_index] = nil
	end
end)

local function onBuildEntity(event)
	local e = event.created_entity
	if not e or not e.valid or not acceptedTypes[e.type] then return end
	local player = game.players[event.player_index]
	if player.driving or (player.vehicle ~= nil and player.vehicle.valid) then return end

	local inv = player.get_inventory(defines.inventory.player_quickbar)
	if not inv or not inv.valid or not inv.is_filtered() then return end

	-- We check for inv.is_filtered first because I presume it's cheaper than can_reach_entity
	if not player.can_reach_entity(e) then return end

	local playerIndex = event.player_index
	if not filterCache[playerIndex] then filterCache[playerIndex] = {} end
	if filterCache[playerIndex] and filterCache[playerIndex][e.name] then
		local f = inv.get_filter(filterCache[playerIndex][e.name])
		if type(f) == "string" and f == e.name then
			if not global.ent then global.ent = {} end
			player.teleport(e.position)
			player.driving = true
			global.ent[player.index] = e
			return -- We are done, just go!
		else
			filterCache[playerIndex][e.name] = nil
		end
	end
	for i = 1, #inv do
		local f = inv.get_filter(i)
		if type(f) == "string" and f == e.name then
			if not global.ent then global.ent = {} end
			filterCache[playerIndex][e.name] = i
			player.teleport(e.position)
			player.driving = true
			global.ent[player.index] = e
			return -- We are done, just go!
		end
	end
end
script.on_event(defines.events.on_built_entity, onBuildEntity)


local function driving(event)
	if not global.ent or not global.ent[event.player_index] then return end
	local player = game.players[event.player_index]
	if not player or not player.valid or player.driving or player.vehicle then return end
	if not pickup[event.player_index] then return end

	-- I'm not even sure we need to check .can_reach. But just to be sure, we do.
	if global.ent[player.index].valid and global.ent[player.index].minable and player.can_reach_entity(global.ent[player.index]) then
		player.mine_entity(global.ent[player.index])
	end
	global.ent[player.index] = nil
end
script.on_event(defines.events.on_player_driving_changed_state, driving)
