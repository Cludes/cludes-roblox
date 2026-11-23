-- Defences: when the alarm goes off, every watched room fills with fire that burns intruders.
-- Owners (players who entered a correct code this session) are never hurt.
-- Kill switches turn every trap off; the purge button sets them all off on purpose.
local CS = game:GetService("CollectionService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local S = Core.S
local sec = Core.House:WaitForChild("Security")
local DAMAGE = 8 -- per 0.25 s tick, so about 3 seconds in the flames

-- one flame sheet per sensor zone, along its floor
local rooms = {}
for _, z in sec:WaitForChild("Zones"):GetChildren() do
	local sheet = Instance.new("Part")
	sheet.Name = "FireSheet"
	sheet.Anchored, sheet.CanCollide, sheet.CanQuery, sheet.CanTouch = true, false, false, false
	sheet.Transparency = 1
	sheet.Size = Vector3.new(z.Size.X * 0.9, 0.4 * S, z.Size.Z * 0.9)
	sheet.CFrame = CFrame.new(z.Position.X, z.Position.Y - z.Size.Y / 2 + 0.8 * S, z.Position.Z)
	sheet.Parent = z

	local flames = Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Rate = 0
	flames.Lifetime = NumberRange.new(0.6, 1.4)
	flames.Speed = NumberRange.new(4 * S, 10 * S)
	flames.SpreadAngle = Vector2.new(15, 15)
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * S), NumberSequenceKeypoint.new(1, 0.1 * S) }) -- embers; the Fire grid below is the flames
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	flames.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 90)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 110, 20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 10)) })
	flames.LightEmission = 1
	flames.Parent = sheet

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Shape = Enum.ParticleEmitterShape.Box
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(2, 4)
	smoke.Speed = NumberRange.new(2 * S, 4 * S)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * S), NumberSequenceKeypoint.new(1, 6 * S) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 40, 40))
	smoke.Parent = sheet

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Range = math.min(60, 24 * S)
	glow.Brightness = 3
	glow.Enabled = false
	glow.Parent = sheet

	-- real flames on a grid across the floor
	local fireList = {}
	local step = 9 * S
	local nx = math.max(1, math.floor(sheet.Size.X / step))
	local nz = math.max(1, math.floor(sheet.Size.Z / step))
	for i = 1, nx do
		for j = 1, nz do
			local spot = Instance.new("Part")
			spot.Name = "FireSpot"
			spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
			spot.Transparency = 1
			spot.Size = Vector3.new(0.2, 0.2, 0.2)
			spot.CFrame = sheet.CFrame * CFrame.new((i - 0.5) / nx * sheet.Size.X - sheet.Size.X / 2, 0, (j - 0.5) / nz * sheet.Size.Z - sheet.Size.Z / 2)
			spot.Parent = sheet
			local f = Instance.new("Fire")
			f.Size = 9 * S
			f.Heat = 12
			f.Enabled = false
			f.Parent = spot
			table.insert(fireList, f)
		end
	end

	table.insert(rooms, { zone = z, flames = flames, smoke = smoke, glow = glow, fires = fireList })
end

local burning = false
local function setFire(on)
	if burning == on then return end
	burning = on
	local area = 0
	for _, r in rooms do
		area = r.zone.Size.X * r.zone.Size.Z
		r.flames.Rate = on and math.clamp(area / 20, 20, 120) or 0
		for _, f in r.fires do f.Enabled = on end
		r.smoke.Rate = on and 20 or 0
		r.glow.Enabled = on
	end
	if on then Core.log("DEFENCES: fire suppression reversed, rooms burning") end
end

-- kill switches (guarded levers) and purge buttons
local function showSwitches()
	local on = Core.get("Defences")
	for _, sw in CS:GetTagged("KillSwitch") do
		local lamp = sw:FindFirstChild("Lamp")
		if lamp then lamp.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 255, 80) end
		local p = sw:FindFirstChildOfClass("ProximityPrompt")
		if p then p.ActionText = on and "Kill all defences" or "Re-arm defences" end
	end
end
for _, sw in CS:GetTagged("KillSwitch") do
	Core.prompt(sw, "Kill all defences", "Kill switch", 1.5, 6).Triggered:Connect(function(p)
		if not Core.Authorized[p] then
			Core.notify("Kill switch locked. Enter the alarm code first.", "warn", p)
			Core.log("Kill switch denied for " .. p.Name)
			return
		end
		Core.set("Defences", not Core.get("Defences"))
		Core.log("Defences " .. (Core.get("Defences") and "RE-ARMED" or "KILLED") .. " by " .. p.Name)
		Core.notify(Core.get("Defences") and "Defences armed" or "All defences killed", Core.get("Defences") and "warn" or "ok")
		showSwitches()
	end)
end
for _, b in CS:GetTagged("PurgeButton") do
	Core.prompt(b, "PURGE", "Purge button", 2, 6).Triggered:Connect(function(p)
		if not Core.Authorized[p] then
			Core.notify("Purge locked. Enter the alarm code first.", "warn", p)
			return
		end
		Core.call("trigger_alarm", "Manual purge by " .. p.Name)
	end)
end
showSwitches()

-- burn intruders, warn owners
local warned = {}
while true do
	local active = Core.get("Security") == "Alarm" and Core.get("Defences") == true
	setFire(active)
	if active then
		for _, r in rooms do
			for _, plr in Core.playersInBox(r.zone.CFrame, r.zone.Size) do
				if Core.lethal(plr) then
					local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
					if hum then hum:TakeDamage(DAMAGE) end
				elseif not warned[plr] then
					warned[plr] = true
					Core.notify("Defences active. You are authorised, the fire will not hurt you.", "info", plr)
				end
			end
		end
	else
		table.clear(warned)
	end
	task.wait(0.25)
end
