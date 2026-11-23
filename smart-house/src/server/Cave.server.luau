-- Cave: the car turntable, the city scan on the giant screen, the waterfall shimmer.
local RunService = game:GetService("RunService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local cave = Core.House:WaitForChild("Cave")
local car = cave:WaitForChild("BatCar")
local tt = cave:WaitForChild("Turntable")
local center = tt.Position
local carBase = car:GetPivot()
local ttBase = tt.CFrame
local angle = 0
RunService.Heartbeat:Connect(function(dt)
	angle += dt * 0.25
	local rot = CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(-center)
	car:PivotTo(rot * carBase)
	tt.CFrame = rot * ttBase
end)

local map = cave:WaitForChild("GiantScreen"):WaitForChild("Screen"):WaitForChild("BG"):WaitForChild("Map")
local blips = {}
for i = 1, 7 do
	local b = Instance.new("Frame")
	b.Size = UDim2.fromOffset(14, 14)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = (i == 1) and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(0, 220, 255)
	b.BorderSizePixel = 0
	b.Position = UDim2.fromScale(math.random(10, 90) / 100, math.random(15, 90) / 100)
	b.Parent = map
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	blips[i] = b
end

local fall = cave:WaitForChild("Waterfall")
local n = 0
while true do
	n += 1
	fall.Transparency = 0.3 + math.random() * 0.12
	if n % 5 == 0 then
		for _, b in blips do
			local p = b.Position
			local x = math.clamp(p.X.Scale + (math.random() - 0.5) * 0.04, 0.05, 0.95)
			local y = math.clamp(p.Y.Scale + (math.random() - 0.5) * 0.04, 0.12, 0.95)
			b.Position = UDim2.fromScale(x, y)
			b.BackgroundTransparency = (n % 10 == 0) and 0.5 or 0
		end
	end
	task.wait(0.1)
end
