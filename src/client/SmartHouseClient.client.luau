-- SmartHouseClient: keypad, control panel, CCTV viewer, notifications, alarm overlay.
-- Everything here is display only. Every action is a request the server checks.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remotes = RS:WaitForChild("SmartHouseRemotes")
local house = workspace:WaitForChild("SmartHouse")

local C = {
	bg = Color3.fromRGB(14, 18, 26), panel = Color3.fromRGB(28, 34, 46), accent = Color3.fromRGB(0, 170, 255),
	ok = Color3.fromRGB(40, 200, 110), warn = Color3.fromRGB(255, 170, 0), bad = Color3.fromRGB(235, 60, 60),
	text = Color3.fromRGB(235, 240, 245), dim = Color3.fromRGB(140, 150, 165),
}

local gui = Instance.new("ScreenGui")
gui.Name = "SmartHouseUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function new(class, props)
	local o = Instance.new(class)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	o.Parent = props.Parent
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = o }) end
local function stroke(o, color, t) new("UIStroke", { Color = color, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
local function button(parent, text, color, size, pos)
	local b = new("TextButton", { Size = size, Position = pos, BackgroundColor3 = color or C.panel, Text = text,
		TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = true, Parent = parent })
	corner(b, 6)
	return b
end
local function window(title, w, h)
	local f = new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2), BackgroundColor3 = C.bg, Visible = false, Parent = gui })
	corner(f, 12)
	stroke(f, C.accent, 2)
	new("TextLabel", { Size = UDim2.new(1, -50, 0, 40), Position = UDim2.fromOffset(16, 6), BackgroundTransparency = 1, Text = title,
		TextColor3 = C.accent, Font = Enum.Font.GothamBlack, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	local x = button(f, "X", C.bad, UDim2.fromOffset(32, 32), UDim2.new(1, -42, 0, 10))
	x.Activated:Connect(function() f.Visible = false end)
	return f
end

---------------- notifications ----------------
local holder = new("Frame", { Size = UDim2.new(0, 440, 1, -80), Position = UDim2.new(0.5, -220, 0, 70), BackgroundTransparency = 1, Parent = gui })
new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = holder })
local KIND = { ok = C.ok, warn = C.warn, alarm = C.bad, info = C.accent }
remotes.Notify.OnClientEvent:Connect(function(text, kind)
	local f = new("TextLabel", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Text = text,
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 16, TextWrapped = true, Parent = holder })
	corner(f)
	stroke(f, KIND[kind] or C.accent, 2)
	task.delay(5, function()
		TweenService:Create(f, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.45)
		f:Destroy()
	end)
end)

---------------- status banner + alarm vignette ----------------
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
local banner = new("TextLabel", { Size = UDim2.fromOffset(380, 46), Position = UDim2.new(0.5, -190, 0, 14), BackgroundColor3 = C.bad,
	TextColor3 = C.text, Font = Enum.Font.GothamBlack, TextSize = 20, Visible = false, Parent = gui })
corner(banner)

---------------- keypad ----------------
local keypad = window("SECURITY KEYPAD", 310, 470)
local display = new("TextLabel", { Size = UDim2.new(1, -32, 0, 56), Position = UDim2.fromOffset(16, 50), BackgroundColor3 = Color3.fromRGB(6, 10, 16),
	Text = "ENTER CODE", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 26, Parent = keypad })
corner(display, 6)
local stateLbl = new("TextLabel", { Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(16, 110), BackgroundTransparency = 1,
	Text = "", TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 14, Parent = keypad })
local entered = ""
local function showEntry()
	display.TextColor3 = C.text
	display.Text = (entered == "") and "ENTER CODE" or string.rep("*", #entered)
end
local function press(k)
	if k == "CLR" then entered = ""
	elseif k == "<" then entered = entered:sub(1, -2)
	elseif #entered < 8 then entered ..= k end
	showEntry()
end
for i, k in { "1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "<" } do
	local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
	local b = button(keypad, k, C.panel, UDim2.fromOffset(84, 48), UDim2.fromOffset(18 + col * 92, 138 + row * 56))
	b.TextSize = 22
	b.Activated:Connect(function() press(k) end)
end
local function send(action)
	remotes.Keypad:FireServer(entered, action)
	entered = ""
	display.Text = "..."
end
button(keypad, "AWAY", C.warn, UDim2.fromOffset(84, 44), UDim2.fromOffset(18, 372)).Activated:Connect(function() send("Away") end)
button(keypad, "STAY", C.accent, UDim2.fromOffset(84, 44), UDim2.fromOffset(110, 372)).Activated:Connect(function() send("Stay") end)
button(keypad, "DISARM", C.ok, UDim2.fromOffset(84, 44), UDim2.fromOffset(202, 372)).Activated:Connect(function() send("Disarm") end)
new("TextLabel", { Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 424), BackgroundTransparency = 1, TextWrapped = true,
	Text = "Away: watches every room.  Stay: only the cave and doors.", TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 12, Parent = keypad })
remotes.Keypad.OnClientEvent:Connect(function(kind, msg, ok)
	if kind ~= "result" then return end
	display.Text = msg
	display.TextColor3 = ok and C.ok or C.bad
	task.delay(1.6, function() if entered == "" then showEntry() end end)
end)
local DIGITS = { [Enum.KeyCode.Zero] = "0", [Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3", [Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.Five] = "5", [Enum.KeyCode.Six] = "6", [Enum.KeyCode.Seven] = "7", [Enum.KeyCode.Eight] = "8", [Enum.KeyCode.Nine] = "9",
	[Enum.KeyCode.KeypadZero] = "0", [Enum.KeyCode.KeypadOne] = "1", [Enum.KeyCode.KeypadTwo] = "2", [Enum.KeyCode.KeypadThree] = "3", [Enum.KeyCode.KeypadFour] = "4",
	[Enum.KeyCode.KeypadFive] = "5", [Enum.KeyCode.KeypadSix] = "6", [Enum.KeyCode.KeypadSeven] = "7", [Enum.KeyCode.KeypadEight] = "8", [Enum.KeyCode.KeypadNine] = "9" }

---------------- control panel ----------------
local panelF = window("SMART HOME CONTROL", 440, 470)
local status = new("TextLabel", { Size = UDim2.new(1, -32, 0, 86), Position = UDim2.fromOffset(16, 48), BackgroundColor3 = Color3.fromRGB(6, 10, 16),
	Text = "", TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Parent = panelF })
corner(status, 6)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), Parent = status })
local ACTIONS = {
	{ "Lights On", "lights_on", C.panel }, { "Lights Off", "lights_off", C.panel },
	{ "Party Mode", "party", Color3.fromRGB(150, 50, 160) }, { "Garage Door", "garage", C.panel },
	{ "Lock / Unlock Door", "door", C.panel }, { "LOCKDOWN", "lockdown", C.bad },
	{ "Daytime", "day", Color3.fromRGB(190, 140, 30) }, { "Night", "night", Color3.fromRGB(40, 50, 110) },
	{ "Cameras", "cameras", C.accent }, { "Security Keypad", "keypad", C.ok },
}
for i, a in ACTIONS do
	local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
	local b = button(panelF, a[1], a[3], UDim2.fromOffset(196, 46), UDim2.fromOffset(16 + col * 212, 146 + row * 62))
	b.Activated:Connect(function() remotes.Panel:FireServer(a[2]) end)
end

---------------- CCTV viewer ----------------
local camUI = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 30, 10), BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = camUI })
local camLabel = new("TextLabel", { Size = UDim2.fromOffset(500, 40), Position = UDim2.fromOffset(30, 24), BackgroundTransparency = 1, Text = "",
	TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Parent = camUI })
local rec = new("TextLabel", { Size = UDim2.fromOffset(120, 40), Position = UDim2.new(1, -150, 0, 24), BackgroundTransparency = 1, Text = "REC",
	TextColor3 = C.bad, Font = Enum.Font.Code, TextSize = 28, Parent = camUI })
local camTime = new("TextLabel", { Size = UDim2.fromOffset(300, 30), Position = UDim2.new(0, 30, 1, -60), BackgroundTransparency = 1, Text = "",
	TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Parent = camUI })
new("TextLabel", { Size = UDim2.fromOffset(400, 30), Position = UDim2.new(0.5, -200, 1, -60), BackgroundTransparency = 1, Text = "Q / E  switch camera     X  exit",
	TextColor3 = C.dim, Font = Enum.Font.Code, TextSize = 18, Parent = camUI })
local prevB = button(camUI, "<", C.panel, UDim2.fromOffset(50, 50), UDim2.new(0, 30, 0.5, -25))
local nextB = button(camUI, ">", C.panel, UDim2.fromOffset(50, 50), UDim2.new(1, -80, 0.5, -25))
local exitB = button(camUI, "EXIT", C.bad, UDim2.fromOffset(90, 40), UDim2.new(1, -120, 1, -70))
local cc = new("ColorCorrectionEffect", { Saturation = -0.6, Contrast = 0.15, TintColor = Color3.fromRGB(210, 255, 220), Enabled = false, Parent = Lighting })

local cams, idx, viewing = {}, 1, false
local function camList()
	local list = CS:GetTagged("CCTV")
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end
local function openCams()
	cams = camList()
	if #cams == 0 then return end
	viewing = true
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 75
	cc.Enabled = true
	camUI.Visible = true
end
local function closeCams()
	viewing = false
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	cc.Enabled = false
	camUI.Visible = false
end
local function step(d) idx = ((idx - 1 + d) % #cams) + 1 end
prevB.Activated:Connect(function() step(-1) end)
nextB.Activated:Connect(function() step(1) end)
exitB.Activated:Connect(closeCams)

---------------- open requests from the server ----------------
local openedAt
remotes.Open.OnClientEvent:Connect(function(which)
	keypad.Visible, panelF.Visible = false, false
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	openedAt = root and root.Position
	if which == "keypad" then
		entered = ""
		showEntry()
		keypad.Visible = true
	elseif which == "panel" then
		panelF.Visible = true
	elseif which == "cameras" then
		openCams()
	end
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if viewing then
		if input.KeyCode == Enum.KeyCode.Q then step(-1)
		elseif input.KeyCode == Enum.KeyCode.E then step(1)
		elseif input.KeyCode == Enum.KeyCode.X then closeCams() end
		return
	end
	if keypad.Visible then
		local d = DIGITS[input.KeyCode]
		if d then press(d)
		elseif input.KeyCode == Enum.KeyCode.Backspace then press("<") end
	end
end)

---------------- per-frame updates ----------------
RunService.RenderStepped:Connect(function()
	local s = house:GetAttribute("Security")
	local cd = house:GetAttribute("Countdown") or 0
	if s == "Arming" then
		banner.Visible = true; banner.BackgroundColor3 = C.warn; banner.Text = "ARMING  -  GET CLEAR  " .. cd
	elseif s == "Entry" then
		banner.Visible = true; banner.BackgroundColor3 = C.warn; banner.Text = "ENTER THE CODE  " .. cd
	elseif s == "Alarm" then
		banner.Visible = true; banner.BackgroundColor3 = C.bad; banner.Text = "ALARM"
	elseif house:GetAttribute("Lockdown") then
		banner.Visible = true; banner.BackgroundColor3 = Color3.fromRGB(200, 100, 0); banner.Text = "LOCKDOWN"
	else
		banner.Visible = false
	end
	vignette.BackgroundTransparency = (s == "Alarm") and (0.78 + 0.15 * math.sin(os.clock() * 8)) or 1

	stateLbl.Text = "System: " .. string.upper(s or "?")
	status.Text = "Security   : " .. string.upper(s or "?") .. ((s == "Armed") and (" (" .. house:GetAttribute("ArmMode") .. ")") or "")
		.. "\nGarage     : " .. tostring(house:GetAttribute("Garage"))
		.. "\nFront door : " .. (house:GetAttribute("DoorLocked") and "Locked" or "Unlocked")
		.. "\nElevator   : " .. tostring(house:GetAttribute("Elevator"))

	if viewing and #cams > 0 then
		local c = cams[idx]
		workspace.CurrentCamera.CFrame = c.CFrame * CFrame.new(0, 0, -1.3)
		camLabel.Text = c:GetAttribute("Label") or c.Name
		local t = Lighting.ClockTime
		camTime.Text = string.format("%02d:%02d:%02d", math.floor(t), math.floor((t % 1) * 60), math.floor(os.clock() % 60))
		rec.TextTransparency = (os.clock() % 1 < 0.5) and 0 or 1
	end

	-- close windows if the player walks away
	if openedAt and (keypad.Visible or panelF.Visible) then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - openedAt).Magnitude > 16 then
			keypad.Visible, panelF.Visible = false, false
		end
	end
end)
