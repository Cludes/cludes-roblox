-- Secrets: the bookcase door, the painting that opens the attic hatch, and the server room LEDs.
local TweenService = game:GetService("TweenService")
local CS = game:GetService("CollectionService")
local Core = require(script.Parent:WaitForChild("HouseCore"))
local s = Core.House:WaitForChild("Secrets")

-- turn `part` (and everything inside it) around a hinge CFrame
local function hinged(part, hinge, axis)
	local rel = hinge:ToObjectSpace(part.CFrame)
	local decor = {}
	for _, c in part:GetDescendants() do
		if c:IsA("BasePart") then table.insert(decor, { part = c, offset = part.CFrame:ToObjectSpace(c.CFrame) }) end
	end
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		local cf = hinge * axis(math.rad(a)) * rel
		part.CFrame = cf
		for _, d in decor do d.part.CFrame = cf * d.offset end
	end)
	return function(angle, time)
		TweenService:Create(v, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = angle }):Play()
	end
end
local function aroundY(a) return CFrame.Angles(0, a, 0) end
local function aroundX(a) return CFrame.Angles(a, 0, 0) end
local function aroundZ(a) return CFrame.Angles(0, 0, a) end

-- bookcase: pull the odd red book
local case = s:WaitForChild("Bookcase")
local moveCase = hinged(case, s:WaitForChild("BookcaseHinge").CFrame, aroundY)
local caseOpen, caseToken = false, 0
local function setCase(open, who)
	if caseOpen == open then return end
	caseOpen = open
	caseToken += 1
	moveCase(open and 85 or 0, 1.6)
	if open then
		Core.log("Secret bookcase opened" .. (who and (" by " .. who) or ""))
		local my = caseToken
		task.delay(20, function()
			if caseToken == my and caseOpen then setCase(false) end
		end)
	end
end
local bookPrompt = Core.prompt(case:WaitForChild("SecretBook"), "Pull", "Old book", 0.4, 6)
bookPrompt.RequiresLineOfSight = false -- the other books block the check
bookPrompt.Triggered:Connect(function(p) setCase(true, p.Name) end)
Core.prompt(s:WaitForChild("SecretLever"), "Bookcase", "Lever", 0, 6).Triggered:Connect(function(p) setCase(not caseOpen, p.Name) end)

-- painting -> attic hatch + ladder
local painting = s:WaitForChild("Painting")
local tilt = hinged(painting, painting.CFrame * CFrame.new(0, 2.5, 0), aroundX)
local moveHatch = hinged(s:WaitForChild("Hatch"), s:WaitForChild("HatchHinge").CFrame, aroundZ)
local ladder = s:WaitForChild("Ladder")
local atticOpen = false
local function setAttic(open, who)
	if atticOpen == open then return end
	atticOpen = open
	tilt(open and 14 or 0, 0.5)
	moveHatch(open and -92 or 0, 1.2)
	if open then
		Core.log("Attic hatch opened" .. (who and (" by " .. who) or ""))
		task.delay(0.9, function()
			if atticOpen then ladder.Transparency = 0; ladder.CanCollide = true end
		end)
	else
		ladder.Transparency = 1
		ladder.CanCollide = false
	end
end
Core.prompt(painting, "Inspect", "Painting", 0.5, 7).Triggered:Connect(function(p) setAttic(not atticOpen, p.Name) end)
Core.prompt(s:WaitForChild("AtticLever"), "Hatch", "Lever", 0, 6).Triggered:Connect(function(p) setAttic(not atticOpen, p.Name) end)

-- server rack LEDs
local leds = CS:GetTagged("ServerLED")
local palette = { Color3.fromRGB(0, 255, 90), Color3.fromRGB(0, 255, 90), Color3.fromRGB(0, 255, 90), Color3.fromRGB(255, 170, 0), Color3.fromRGB(10, 40, 20) }
while #leds > 0 do
	for _ = 1, 12 do
		leds[math.random(#leds)].Color = palette[math.random(#palette)]
	end
	task.wait(0.12)
end
