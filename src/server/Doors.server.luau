-- Doors: smart-locked front door (forcing it while locked trips the alarm) and a doorbell.
local TweenService = game:GetService("TweenService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local d = Core.House:WaitForChild("Doors")
local door = d:WaitForChild("FrontDoor")
local hinge = d:WaitForChild("Hinge").CFrame
local rel = hinge:ToObjectSpace(door.CFrame)
local led = door:WaitForChild("LockLED")
local decor = {}
for _, c in door:GetChildren() do
	if c:IsA("BasePart") then table.insert(decor, { part = c, offset = door.CFrame:ToObjectSpace(c.CFrame) }) end
end

local angle = Instance.new("NumberValue")
angle.Changed:Connect(function(a)
	local cf = hinge * CFrame.Angles(0, math.rad(a), 0) * rel
	door.CFrame = cf
	for _, dc in decor do dc.part.CFrame = cf * dc.offset end
end)

local prompt = Core.prompt(door, "Open", "Front door", 0, 7)
local isOpen, token = false, 0

local function refresh()
	local locked = Core.get("DoorLocked") == true
	led.Color = locked and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 255, 80)
	if locked and not isOpen then
		prompt.ActionText = "Force open"
		prompt.ObjectText = "Front door (locked)"
		prompt.HoldDuration = 3
	else
		prompt.ActionText = isOpen and "Close" or "Open"
		prompt.ObjectText = "Front door"
		prompt.HoldDuration = 0
	end
end

local function swing(open)
	isOpen = open
	token += 1
	Core.set("DoorOpen", open)
	TweenService:Create(angle, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = open and 95 or 0 }):Play()
	refresh()
	if open then
		local my = token
		task.delay(7, function()
			if token == my and isOpen then swing(false) end
		end)
	end
end

prompt.Triggered:Connect(function(player)
	if isOpen then
		swing(false)
	elseif Core.get("DoorLocked") then
		Core.call("security_breach", "Front door forced by " .. player.Name)
		swing(true)
	else
		swing(true)
	end
end)

Core.register("door_lock", function(locked, who)
	Core.set("DoorLocked", locked)
	if locked and isOpen then swing(false) end
	refresh()
	if who then Core.log("Front door " .. (locked and "locked" or "unlocked") .. " by " .. who) end
end)

-- doorbell
local bell = d:WaitForChild("Doorbell")
local lastRing = 0
Core.prompt(d:WaitForChild("DoorbellButton"), "Ring", "Doorbell", 0, 6).Triggered:Connect(function(player)
	if os.clock() - lastRing < 4 then return end
	lastRing = os.clock()
	bell.Chime:Play()
	local panelChime = Core.House.Security.SmartPanel:FindFirstChild("Chime")
	if panelChime then panelChime:Play() end
	Core.notify("Ding dong! " .. player.Name .. " is at the front door", "info")
	Core.log("Doorbell rung by " .. player.Name)
end)

refresh()
