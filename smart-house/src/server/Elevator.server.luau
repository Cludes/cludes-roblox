-- Elevator: a physics car on a PrismaticConstraint servo between the kitchen and the cave.
-- Pull the grandfather clock's pendulum to slide it aside and call the car up.
local TweenService = game:GetService("TweenService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local el = Core.House:WaitForChild("Elevator")
local car = el:WaitForChild("Car")
local floor = car:WaitForChild("Floor")
local lift = el:WaitForChild("Rail"):WaitForChild("Lift")
local clock = el:WaitForChild("Clock")
local TRAVEL = el:GetAttribute("Travel")

floor:SetNetworkOwner(nil) -- the server drives the car, so no client can fling it

local function slider(part, offset)
	local closed = part.CFrame
	local decor = {}
	for _, c in part:GetDescendants() do
		if c:IsA("BasePart") then table.insert(decor, { part = c, offset = closed:ToObjectSpace(c.CFrame) }) end
	end
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(t)
		local cf = closed + offset * t
		part.CFrame = cf
		for _, d in decor do d.part.CFrame = cf * d.offset end
	end)
	return function(open, time)
		TweenService:Create(v, TweenInfo.new(time or 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = open and 1 or 0 }):Play()
	end
end

local doors = {
	House = { slider(el:WaitForChild("DoorHouseL"), Vector3.new(-2, 0, 0) * Core.S), slider(el:WaitForChild("DoorHouseR"), Vector3.new(2, 0, 0) * Core.S) },
	Cave = { slider(el:WaitForChild("DoorCaveL"), Vector3.new(-2, 0, 0) * Core.S), slider(el:WaitForChild("DoorCaveR"), Vector3.new(2, 0, 0) * Core.S) },
}
local function setDoors(level, open)
	for _, f in doors[level] do f(open) end
end

local moveClock = slider(clock, Vector3.new(-4.4, 0, 0) * Core.S)
local clockOpen, clockToken = false, 0
local function setClock(open)
	if clockOpen == open then return end
	clockOpen = open
	clockToken += 1
	moveClock(open, 1.4)
	if open then
		local my = clockToken
		task.spawn(function()
			repeat task.wait(25) until clockToken ~= my or Core.get("Elevator") ~= "House"
			if clockToken == my then setClock(false) end
		end)
	end
end

local level, busy = "Cave", false
local panelPrompt = Core.prompt(car:WaitForChild("Panel"), "Go up", "Elevator", 0, 6)
panelPrompt.RequiresLineOfSight = false

local function go(target)
	if busy or level == target then return end
	busy = true
	setDoors(level, false)
	Core.set("Elevator", "Moving")
	task.wait(0.9)
	lift.TargetPosition = (target == "House") and TRAVEL or 0
	local t0 = os.clock()
	while math.abs(lift.CurrentPosition - lift.TargetPosition) > 0.15 and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	level = target
	Core.set("Elevator", target)
	if target == "House" then setClock(true) end
	setDoors(target, true)
	panelPrompt.ActionText = (target == "House") and "Go down" or "Go up"
	busy = false
end

panelPrompt.Triggered:Connect(function()
	go(level == "House" and "Cave" or "House")
end)
local pendPrompt = Core.prompt(clock:WaitForChild("Pendulum"), "Pull pendulum", "Grandfather clock", 0.5, 6)
pendPrompt.RequiresLineOfSight = false -- the clock glass blocks the check
pendPrompt.Triggered:Connect(function(p)
	Core.log("Secret elevator called by " .. p.Name)
	setClock(true)
	go("House")
end)
Core.prompt(el:WaitForChild("CallButton"), "Call elevator", "Elevator", 0, 6).Triggered:Connect(function()
	go("Cave")
end)

Core.set("Elevator", "Cave")
setDoors("Cave", true)
