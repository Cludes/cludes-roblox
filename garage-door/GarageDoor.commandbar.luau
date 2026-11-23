-- Garage door builder: paste this whole file into Studio's Command Bar (View > Command Bar) and press Enter.
-- It builds a small garage with a four-panel door, status lamps, two buttons and the script that runs it.
-- Re-running it deletes the earlier House model and GarageDoor script first.
local SSS = game:GetService("ServerScriptService")
if workspace:FindFirstChild("House") then workspace.House:Destroy() end
if SSS:FindFirstChild("GarageDoor") then SSS.GarageDoor:Destroy() end

local house = Instance.new("Model"); house.Name = "House"; house.Parent = workspace
local garage = Instance.new("Folder"); garage.Name = "Garage"; garage.Parent = house

local function mk(parent, name, size, pos, color, mat, transp)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color, p.Material = name, size, pos, color, mat
	p.Anchored = true
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function light(part, color, range, brightness, on)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Enabled = color, range, brightness, on
	l.Parent = part
	return l
end

local brick = Color3.fromRGB(165, 105, 85)
local white = Color3.fromRGB(240, 240, 240)
local grey = Color3.fromRGB(110, 110, 115)

-- facade (opening is x -8..8, y 0..12)
mk(garage, "WallLeft", Vector3.new(10, 25, 1), Vector3.new(-13, 12.5, 0.5), brick, Enum.Material.Brick)
mk(garage, "WallRight", Vector3.new(10, 25, 1), Vector3.new(13, 12.5, 0.5), brick, Enum.Material.Brick)
mk(garage, "WallTop", Vector3.new(16, 13, 1), Vector3.new(0, 18.5, 0.5), brick, Enum.Material.Brick)
mk(garage, "TrimTop", Vector3.new(18, 1, 1.4), Vector3.new(0, 12.5, 0.7), white, Enum.Material.Concrete)
mk(garage, "TrimLeft", Vector3.new(1, 12, 1.4), Vector3.new(-8.5, 6, 0.7), white, Enum.Material.Concrete)
mk(garage, "TrimRight", Vector3.new(1, 12, 1.4), Vector3.new(8.5, 6, 0.7), white, Enum.Material.Concrete)

-- interior
mk(garage, "Floor", Vector3.new(17, 0.2, 15), Vector3.new(0, 0.1, -7.5), Color3.fromRGB(70, 70, 75), Enum.Material.Concrete)
mk(garage, "SideLeft", Vector3.new(1, 25, 15), Vector3.new(-8.5, 12.5, -7.5), grey, Enum.Material.Concrete)
mk(garage, "SideRight", Vector3.new(1, 25, 15), Vector3.new(8.5, 12.5, -7.5), grey, Enum.Material.Concrete)
mk(garage, "Back", Vector3.new(18, 25, 1), Vector3.new(0, 12.5, -15), grey, Enum.Material.Concrete)
mk(garage, "Roof", Vector3.new(19, 1, 16.5), Vector3.new(0, 24.6, -7.25), Color3.fromRGB(60, 60, 65), Enum.Material.Concrete)
local glow = mk(garage, "InteriorLight", Vector3.new(1, 1, 1), Vector3.new(0, 11, -6), white, Enum.Material.SmoothPlastic, 1)
glow.CanCollide = false
light(glow, Color3.fromRGB(255, 240, 210), 30, 2, false).Name = "InteriorPointLight"

-- door: four panels in a model, recessed behind the facade so it slides up behind the wall
local door = Instance.new("Model"); door.Name = "Door"; door.Parent = garage
local first
for i = 0, 3 do
	local p = mk(door, "Panel" .. i, Vector3.new(15.8, 2.9, 1), Vector3.new(0, 1.5 + i * 3, -0.5), Color3.fromRGB(225, 225, 230), Enum.Material.Metal)
	first = first or p
end
door.PrimaryPart = first
for i = 0, 3 do
	local x = -5.25 + i * 3.5
	mk(door, "Window" .. i, Vector3.new(3, 1.4, 0.2), Vector3.new(x, 10.5, 0.05), Color3.fromRGB(150, 200, 230), Enum.Material.Glass, 0.35)
end
mk(door, "Handle", Vector3.new(3, 0.3, 0.3), Vector3.new(0, 1.6, 0.2), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)

local lift = Instance.new("NumberValue"); lift.Name = "Lift"; lift.Parent = garage

-- status lamps above the door
local lamps = Instance.new("Folder"); lamps.Name = "Lamps"; lamps.Parent = garage
for name, data in { Red = { -2, Color3.fromRGB(255, 0, 0) }, Orange = { 0, Color3.fromRGB(255, 150, 0) }, Green = { 2, Color3.fromRGB(0, 255, 0) } } do
	local lamp = mk(lamps, name, Vector3.new(1.2, 1.2, 0.4), Vector3.new(data[1], 21, 1.2), data[2], Enum.Material.Plastic)
	light(lamp, data[2], 8, 1.5, false)
end

-- buttons: outside on the right wall, inside on the right side wall
mk(garage, "ButtonPlate", Vector3.new(2, 3, 0.3), Vector3.new(10, 4, 1.15), Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
mk(garage, "Button", Vector3.new(1, 1, 0.5), Vector3.new(10, 4, 1.4), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
mk(garage, "ButtonInside", Vector3.new(0.5, 1, 1), Vector3.new(7.75, 4, -3), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)

local s = Instance.new("Script")
s.Name = "GarageDoor"
s.Source = [==[
local TweenService = game:GetService("TweenService")
local garage = workspace:WaitForChild("House"):WaitForChild("Garage")
local door = garage:WaitForChild("Door")
local lift = garage:WaitForChild("Lift")
local lamps = garage:WaitForChild("Lamps")
local glow = garage:WaitForChild("InteriorLight"):WaitForChild("InteriorPointLight")

local OPEN_H = 12.1
local OPEN_TIME = 2.5      -- seconds to fully open
local CLOSE_TIME = 8       -- seconds to fully close (slow on purpose)
local AUTO_CLOSE = 12      -- seconds the door stays open

local base = door:GetPivot()
lift.Changed:Connect(function(v)
	door:PivotTo(base * CFrame.new(0, v, 0))
end)

local state = "closed" -- closed, opening, open, closing
local token = 0

local function lamp(name, on)
	local p = lamps[name]
	p.Material = on and Enum.Material.Neon or Enum.Material.Plastic
	p:FindFirstChildOfClass("PointLight").Enabled = on
end

local function showStatus()
	lamp("Red", state == "closed")
	lamp("Green", state == "open")
	if state == "opening" or state == "closing" then
		local my = token
		task.spawn(function()
			local on = true
			while token == my and (state == "opening" or state == "closing") do
				lamp("Orange", on)
				on = not on
				task.wait(0.4)
			end
			lamp("Orange", false)
		end)
	else
		lamp("Orange", false)
	end
end

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { garage }

local function blocked()
	local parts = workspace:GetPartBoundsInBox(CFrame.new(0, 6.25, -0.5), Vector3.new(15, 11.5, 4), params)
	for _, p in parts do
		local m = p:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") then return true end
	end
	return false
end

local function setDoor(open)
	token += 1
	local my = token
	state = open and "opening" or "closing"
	showStatus()

	local goal = open and OPEN_H or 0
	local full = open and OPEN_TIME or CLOSE_TIME
	local dur = math.max(full * math.abs(goal - lift.Value) / OPEN_H, 0.05)
	local tw = TweenService:Create(lift, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = goal })
	local done = false
	tw.Completed:Connect(function() done = true end)
	if open then glow.Enabled = true end
	tw:Play()

	while not done do
		if my ~= token then tw:Cancel() return end
		if not open and blocked() then
			tw:Cancel()
			task.spawn(setDoor, true) -- safety: someone is in the doorway, reopen
			return
		end
		task.wait(0.05)
	end
	if my ~= token then return end

	state = open and "open" or "closed"
	if not open then glow.Enabled = false end
	showStatus()
	if open then
		task.delay(AUTO_CLOSE, function()
			if token == my and state == "open" then setDoor(false) end
		end)
	end
end

for _, name in { "Button", "ButtonInside" } do
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Garage door"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.Parent = garage:WaitForChild(name)
	prompt.Triggered:Connect(function()
		setDoor(not (state == "open" or state == "opening"))
	end)
end

showStatus()
]==]
s.Parent = SSS

print("Garage built. Press Play and walk to the red button on the right of the door.")
