-- Rooms: the back wing. A film plays in the cinema, and spinning the library globe slides
-- a bookshelf aside to reveal the hidden panic room.
local TweenService = game:GetService("TweenService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local rooms = Core.House:WaitForChild("BackWing"):WaitForChild("Rooms")
local library = rooms:WaitForChild("Library")

---------------- panic room door ----------------
local door = library:WaitForChild("PanicDoor")
local closed = door.CFrame
local decor = {}
for _, c in door:GetDescendants() do
	if c:IsA("BasePart") then table.insert(decor, { part = c, offset = closed:ToObjectSpace(c.CFrame) }) end
end
local v = Instance.new("NumberValue")
v.Changed:Connect(function(t)
	local cf = closed + Vector3.new(0, 0, -4 * Core.S) * t
	door.CFrame = cf
	for _, d in decor do d.part.CFrame = cf * d.offset end
end)

local open, token = false, 0
local function setDoor(state, who)
	if open == state then return end
	open = state
	token += 1
	TweenService:Create(v, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = state and 1 or 0 }):Play()
	if state then
		Core.log("Panic room opened" .. (who and (" by " .. who) or ""))
		local my = token
		task.delay(20, function() if token == my then setDoor(false) end end)
	end
end

local globe = library:WaitForChild("Globe")
local spinning = false
local globePrompt = Core.prompt(globe, "Spin", "Globe", 0.5, 6)
globePrompt.Triggered:Connect(function(p)
	if not spinning then
		spinning = true
		local start = globe.CFrame
		task.spawn(function()
			for i = 1, 30 do
				globe.CFrame = start * CFrame.Angles(0, math.rad(i * 24), 0)
				task.wait(0.03)
			end
			globe.CFrame = start
			spinning = false
		end)
	end
	setDoor(not open, p.Name)
end)
Core.prompt(rooms:WaitForChild("PanicRoom"):WaitForChild("InsideLever"), "Bookshelf", "Lever", 0, 6).Triggered:Connect(function(p)
	setDoor(not open, p.Name)
end)

---------------- cinema ----------------
local film = rooms:WaitForChild("Cinema"):WaitForChild("Screen"):WaitForChild("Film"):WaitForChild("BG")
local sky = film:WaitForChild("Sky")
local title = film:WaitForChild("Title")
local scenes = {
	{ "NOW SHOWING", Color3.fromRGB(20, 20, 40), Color3.fromRGB(80, 40, 120) },
	{ "THE CAVE RISES", Color3.fromRGB(10, 10, 20), Color3.fromRGB(0, 90, 160) },
	{ "NIGHT FALLS ON THE CITY", Color3.fromRGB(30, 10, 40), Color3.fromRGB(200, 80, 60) },
	{ "THE SIGNAL IS LIT", Color3.fromRGB(10, 10, 20), Color3.fromRGB(230, 200, 90) },
}
local i = 0
while true do
	i = i % #scenes + 1
	local s = scenes[i]
	title.Text = s[1]
	sky.Color = ColorSequence.new(s[2], s[3])
	for k = 0, 40 do
		sky.Offset = Vector2.new(0, math.sin(k / 40 * math.pi) * 0.3)
		task.wait(0.1)
	end
end
