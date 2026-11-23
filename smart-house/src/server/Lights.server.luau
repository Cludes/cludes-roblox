-- Lights: room switches, all on/off, party mode, alarm flashing,
-- a day/night cycle, and exterior lights that switch on at dusk.
local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local DAY_MINUTES = 8 -- one full day lasts this many real minutes
local OFF = Color3.fromRGB(235, 233, 226)
local HIDDEN = { Secret = true, Attic = true, Vault = true } -- "all lights" never reveals the hidden rooms

local lights = {}
for _, p in CS:GetTagged("SmartLight") do
	lights[p] = { light = p:FindFirstChildOfClass("PointLight"), room = p:GetAttribute("Room"),
		motion = p:GetAttribute("Motion") == true, base = p.Color,
		warm = p:FindFirstChildOfClass("PointLight").Color }
end
local roomOn = {}
local mode = "Normal" -- Normal, Party, Alarm

local function paint(p, on, color)
	local d = lights[p]
	d.light.Enabled = on
	d.light.Color = color or d.warm
	p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Color = on and (color or d.base) or OFF
end

local function isNight()
	local t = Lighting.ClockTime
	return t >= 18 or t < 6.5
end

local function someoneNear(part, dist)
	for _, plr in Players:GetPlayers() do
		local root = Core.rootOf(plr)
		if root and (root.Position - part.Position).Magnitude <= dist then return true end
	end
	return false
end

for _, sw in CS:GetTagged("LightSwitch") do
	local room = sw:GetAttribute("Room")
	local pr = Core.prompt(sw, "Toggle lights", room .. " lights", 0, 7)
	pr.Triggered:Connect(function()
		roomOn[room] = not roomOn[room]
	end)
end

Core.register("lights_all", function(on)
	for _, d in lights do
		if d.room ~= "Exterior" and not HIDDEN[d.room] then roomOn[d.room] = on end
	end
end)
Core.register("lights_party", function()
	if mode == "Alarm" then return end
	mode = (mode == "Party") and "Normal" or "Party"
end)
Core.register("lights_alarm", function(on)
	mode = on and "Alarm" or "Normal"
end)
Core.register("time_set", function(hour)
	Lighting.ClockTime = hour
end)

RunService.Heartbeat:Connect(function(dt)
	Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / (DAY_MINUTES * 60)) % 24
end)

local tv = Core.House:WaitForChild("Furniture"):WaitForChild("TV")
local tvText = tv:WaitForChild("Screen"):WaitForChild("Frame"):WaitForChild("Text")

local n = 0
while true do
	n += 1
	local night = isNight()
	local forceExterior = Core.get("Lockdown") == true or mode == "Alarm"
	local flashOn = (n % 8) < 4
	local hue = (n * 0.02) % 1
	local i = 0
	for p, d in lights do
		i += 1
		if d.room == "Exterior" then
			paint(p, forceExterior or (night and (not d.motion or someoneNear(p, 30 * Core.S))))
		elseif mode == "Alarm" then
			paint(p, flashOn, Color3.fromRGB(255, 30, 30))
		elseif mode == "Party" then
			paint(p, true, Color3.fromHSV((hue + i * 0.13) % 1, 0.9, 1))
		else
			paint(p, roomOn[d.room] == true)
		end
	end
	if n % 10 == 0 then
		tvText.Text = "SMART HOME  " .. Core.clock()
	end
	task.wait(0.1)
end
