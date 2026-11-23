-- TerraceDoor: an automatic sliding glass door that opens when someone walks up to it.
local TweenService = game:GetService("TweenService")
local Core = require(script.Parent:WaitForChild("HouseCore"))
local Players = game:GetService("Players")

local door = Core.House:WaitForChild("Upstairs"):WaitForChild("TerraceDoor")
local closed = door.CFrame
local decor = {}
for _, c in door:GetDescendants() do
	if c:IsA("BasePart") then table.insert(decor, { part = c, offset = closed:ToObjectSpace(c.CFrame) }) end
end
local v = Instance.new("NumberValue")
v.Changed:Connect(function(t)
	local cf = closed + Vector3.new(0, 0, -5) * Core.S * t
	door.CFrame = cf
	for _, d in decor do d.part.CFrame = cf * d.offset end
end)

local open = false
while true do
	local near = false
	for _, plr in Players:GetPlayers() do
		local root = Core.rootOf(plr)
		if root and (root.Position - closed.Position).Magnitude < 8 * Core.S then near = true break end
	end
	if near ~= open then
		open = near
		TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = open and 1 or 0 }):Play()
	end
	task.wait(0.2)
end
