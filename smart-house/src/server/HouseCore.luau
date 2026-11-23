-- HouseCore: shared state, logging and helpers for every smart house script.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

local Core = {}
Core.House = workspace:WaitForChild("SmartHouse")
Core.Remotes = RS:WaitForChild("SmartHouseRemotes")
-- The alarm code is a ServerStorage attribute, so it never appears in source control.
-- Set it in Studio: ServerStorage > Attributes > AlarmCode. If it is missing, a random code is made.
Core.CODE = game:GetService("ServerStorage"):GetAttribute("AlarmCode")
if typeof(Core.CODE) ~= "string" or Core.CODE == "" then
	Core.CODE = tostring(math.random(1000, 9999))
	warn("[SmartHouse] No AlarmCode attribute on ServerStorage. Using random code " .. Core.CODE)
end
Core.Handlers = {}
Core.LogLines = {}
Core.LogChanged = Instance.new("BindableEvent")
Core.S = Core.House:GetAttribute("Scale") or 1 -- the house can be scaled; distances scale with it
Core.Authorized = {} -- players who entered a correct code this session (the owners)

-- defaults (attributes replicate, so clients and screens can read them)
local defaults = { Security = "Disarmed", ArmMode = "Away", Countdown = 0, Garage = "Closed",
	DoorLocked = false, DoorOpen = false, Lockdown = false, FailedLogins = 0, Defences = true, BatSignal = false }
for k, v in defaults do Core.House:SetAttribute(k, v) end

function Core.clock()
	local t = Lighting.ClockTime
	return string.format("%02d:%02d", math.floor(t), math.floor((t % 1) * 60))
end

function Core.log(msg)
	table.insert(Core.LogLines, 1, Core.clock() .. "  " .. msg)
	if #Core.LogLines > 14 then table.remove(Core.LogLines) end
	Core.LogChanged:Fire()
	print("[SmartHouse] " .. msg)
end

function Core.notify(text, kind, player)
	if player then
		Core.Remotes.Notify:FireClient(player, text, kind)
	else
		Core.Remotes.Notify:FireAllClients(text, kind)
	end
end

-- scripts register actions here so they can call each other without hard links
function Core.register(name, fn) Core.Handlers[name] = fn end
function Core.call(name, ...)
	local fn = Core.Handlers[name]
	if fn then return fn(...) end
	warn("[SmartHouse] no handler for " .. name)
end

function Core.get(k) return Core.House:GetAttribute(k) end
function Core.set(k, v) Core.House:SetAttribute(k, v) end

function Core.authorize(player) Core.Authorized[player] = true end
-- traps only hurt players who have not proved they own the house
function Core.lethal(player) return Core.get("Defences") == true and not Core.Authorized[player] end

function Core.prompt(part, action, object, hold, dist)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object or ""
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = (dist or 8) * Core.S
	p.Parent = part
	return p
end

function Core.rootOf(player)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

function Core.near(player, part, dist)
	local root = Core.rootOf(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= dist
end

function Core.inBox(pos, cf, size)
	local p = cf:PointToObjectSpace(pos)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

function Core.playersInBox(cf, size)
	local list = {}
	for _, plr in Players:GetPlayers() do
		local root = Core.rootOf(plr)
		if root and Core.inBox(root.Position, cf, size) then table.insert(list, plr) end
	end
	return list
end

return Core
