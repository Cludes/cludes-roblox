-- Garage: a sectional door whose panels roll up a curved track onto the ceiling.
-- Slow close, status lamps, safety beam that reverses the door, auto-close.
local TweenService = game:GetService("TweenService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local g = Core.House:WaitForChild("Garage")
local origin = g:WaitForChild("TrackOrigin").CFrame
local lamps = g:WaitForChild("Lamps")
local motor = g:WaitForChild("Opener")
local motorLight = motor:WaitForChild("OpenerLight")
local motorSound = motor:WaitForChild("MotorSound")
local beam = g:WaitForChild("SafetyBeam")

local OPEN_TIME, CLOSE_TIME, AUTO_CLOSE = 4, 9, 45
local S = Core.S
local LIFT_OPEN = 13 * S
local PANEL_H = 3 * S
local R, YT = 1.5 * S, 12.6 * S   -- track bend radius and ceiling track height
local L1 = YT - R                  -- straight vertical part
local L2 = math.pi * R / 2         -- curved part

-- position along the track -> CFrame (relative to TrackOrigin)
local function pathCF(s)
	if s <= L1 then
		return CFrame.new(0, s, 0)
	elseif s <= L1 + L2 then
		local a = (s - L1) / R
		return CFrame.new(0, L1 + R * math.sin(a), -R + R * math.cos(a)) * CFrame.Angles(-a, 0, 0)
	end
	return CFrame.new(0, YT, -R - (s - L1 - L2)) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local panels = {}
for i = 0, 3 do
	local p = g:WaitForChild("Panel" .. i)
	local decor = {}
	for _, c in p:GetChildren() do
		if c:IsA("BasePart") then table.insert(decor, { part = c, offset = p.CFrame:ToObjectSpace(c.CFrame) }) end
	end
	panels[i] = { part = p, decor = decor }
end

local lift = Instance.new("NumberValue")
lift.Changed:Connect(function(v)
	for i, d in panels do
		local cf = origin * pathCF(v + i * PANEL_H + PANEL_H / 2)
		d.part.CFrame = cf
		for _, dc in d.decor do dc.part.CFrame = cf * dc.offset end
	end
end)

local BOX_CF = origin * CFrame.new(0, 6.25 * S, 0)
local BOX_SIZE = Vector3.new(15.5, 11.5, 4.5) * S
local token = 0

local function lamp(name, on)
	local l = lamps[name]
	l.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	l:FindFirstChildOfClass("PointLight").Enabled = on
end

local function showState(state)
	local moving = state == "Opening" or state == "Closing"
	lamp("Red", state == "Closed")
	lamp("Green", state == "Open")
	motorLight.Enabled = state ~= "Closed"
	if not moving then lamp("Orange", false) return end
	local my = token
	task.spawn(function()
		local on = true
		while token == my and (Core.get("Garage") == "Opening" or Core.get("Garage") == "Closing") do
			lamp("Orange", on)
			on = not on
			task.wait(0.35)
		end
	end)
end

local function move(open, who)
	if open and Core.get("Lockdown") then return false, "Lockdown is on" end
	local state = Core.get("Garage")
	if state == (open and "Open" or "Closed") or state == (open and "Opening" or "Closing") then return true end
	token += 1
	local my = token
	Core.set("Garage", open and "Opening" or "Closing")
	showState(Core.get("Garage"))
	motorSound.TimePosition = 0
	motorSound:Play()

	local goal = open and LIFT_OPEN or 0
	local dur = math.max((open and OPEN_TIME or CLOSE_TIME) * math.abs(goal - lift.Value) / LIFT_OPEN, 0.1)
	local tw = TweenService:Create(lift, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = goal })
	local done = false
	tw.Completed:Connect(function() done = true end)
	tw:Play()
	while not done do
		if token ~= my then tw:Cancel() return true end
		if not open and #Core.playersInBox(BOX_CF, BOX_SIZE) > 0 then
			tw:Cancel()
			Core.log("Garage safety beam blocked, reversing")
			task.spawn(function()
				for _ = 1, 6 do beam.Transparency = 0; task.wait(0.1); beam.Transparency = 0.5; task.wait(0.1) end
			end)
			task.spawn(move, true)
			return true
		end
		task.wait(0.05)
	end
	motorSound:Stop()
	Core.set("Garage", open and "Open" or "Closed")
	showState(Core.get("Garage"))
	if who then Core.log("Garage " .. (open and "opened" or "closed") .. " by " .. who) end
	if open then
		task.delay(AUTO_CLOSE, function()
			if token == my and Core.get("Garage") == "Open" then move(false, "auto-close") end
		end)
	end
	return true
end

local function toggle(player, outside)
	local state = Core.get("Garage")
	local opening = not (state == "Open" or state == "Opening")
	if outside and opening and Core.get("Security") ~= "Disarmed" then
		Core.notify("System is armed. Disarm at the keypad first.", "warn", player)
		return
	end
	local ok, why = move(opening, player.Name)
	if ok == false then Core.notify(why, "warn", player) end
end

Core.prompt(g:WaitForChild("ButtonOutside"), "Garage door", "Garage", 0.3, 7).Triggered:Connect(function(p) toggle(p, true) end)
Core.prompt(g:WaitForChild("ButtonInside"), "Garage door", "Garage", 0.3, 7).Triggered:Connect(function(p) toggle(p, false) end)

Core.register("garage_close", function(who) task.spawn(move, false, who) end)
Core.register("garage_toggle", function(who)
	local s = Core.get("Garage")
	task.spawn(function()
		local ok, why = move(not (s == "Open" or s == "Opening"), who)
		if ok == false then Core.notify(why, "warn") end
	end)
end)

showState("Closed")
