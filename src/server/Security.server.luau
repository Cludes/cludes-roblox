-- Security: alarm states, server-checked keypad, motion sensors, sirens, lockdown, screens.
-- The client only ever sends a guess. The code, the state and every decision live here.
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local house = Core.House
local sec = house:WaitForChild("Security")
local secrets = house:WaitForChild("Secrets")
local cave = house:WaitForChild("Cave")
local remotes = Core.Remotes

local EXIT_DELAY, ENTRY_DELAY, SIREN_MAX = 15, 15, 90
local MAX_FAILS, LOCKOUT = 3, 30
local PERIMETER = { Cave = true } -- still watched in Stay mode

local console = cave:WaitForChild("ConsoleDesk")
CS:AddTag(console, "Keypad")
CS:AddTag(console, "ControlPoint")

local panel = sec:WaitForChild("SmartPanel")
local sirens = { panel:WaitForChild("Siren"), sec:WaitForChild("SirenBox"):WaitForChild("Siren") }
local strobes = CS:GetTagged("Strobe")
local keypads = CS:GetTagged("Keypad")
local controlPoints = CS:GetTagged("ControlPoint")

local token = 0
local fails, lockedUntil, lastKey, lastPanel = {}, {}, {}, {}
local failedTotal = 0

local function beep()
	for _, k in keypads do
		local b = k:FindFirstChild("Beep")
		if b then b:Play() end
	end
end
local function setState(s, cd)
	token += 1
	Core.set("Security", s)
	Core.set("Countdown", cd or 0)
end
local function sirensOn(on)
	for _, s in sirens do if on then s:Play() else s:Stop() end end
end

local function triggerAlarm(reason)
	if Core.get("Security") == "Alarm" then return end
	setState("Alarm")
	local my = token
	Core.log("ALARM: " .. reason)
	Core.notify("ALARM! " .. reason, "alarm")
	sirensOn(true)
	Core.call("lights_alarm", true)
	Core.call("garage_close")
	Core.call("door_lock", true)
	task.delay(SIREN_MAX, function()
		if token == my then sirensOn(false) end
	end)
end

local function countdown(state, seconds, onDone)
	setState(state, seconds)
	local my = token
	task.spawn(function()
		for t = seconds, 1, -1 do
			if token ~= my then return end
			Core.set("Countdown", t)
			beep()
			task.wait(1)
		end
		if token == my then onDone() end
	end)
end

local function arm(mode, who)
	Core.set("ArmMode", mode)
	Core.log("Arming (" .. mode .. ") by " .. who)
	Core.notify("Arming " .. mode .. ": " .. EXIT_DELAY .. " seconds to get clear", "info")
	countdown("Arming", EXIT_DELAY, function()
		setState("Armed")
		Core.call("door_lock", true)
		Core.call("garage_close")
		Core.log("System ARMED (" .. mode .. ")")
		Core.notify("System armed (" .. mode .. ")", "ok")
	end)
end

local function disarm(who)
	setState("Disarmed")
	sirensOn(false)
	Core.call("lights_alarm", false)
	Core.set("Lockdown", false)
	Core.call("door_lock", false)
	Core.log("System disarmed by " .. who)
	Core.notify("System disarmed", "ok")
end

local function lockdown(who, panic)
	Core.set("Lockdown", true)
	Core.call("garage_close")
	Core.call("door_lock", true)
	Core.log((panic and "PANIC BUTTON" or "Lockdown") .. " by " .. who)
	if panic then
		triggerAlarm("Panic button pressed by " .. who)
	else
		Core.notify("LOCKDOWN: front door locked, garage sealed", "warn")
	end
end

Core.register("trigger_alarm", triggerAlarm)
Core.register("security_breach", function(reason)
	local s = Core.get("Security")
	if s == "Armed" or s == "Entry" or Core.get("Lockdown") then
		triggerAlarm(reason)
	else
		Core.log(reason)
	end
end)

-- motion sensors
local zones = {}
for _, z in sec:WaitForChild("Zones"):GetChildren() do zones[z:GetAttribute("Room")] = z end
local leds = {}
for _, dev in CS:GetTagged("MotionSensor") do leds[dev:GetAttribute("Room")] = dev:WaitForChild("LED") end

task.spawn(function()
	while true do
		for room, z in zones do
			local hit = #Core.playersInBox(z.CFrame, z.Size) > 0
			local led = leds[room]
			if led then led.Color = hit and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(60, 0, 0) end
			if hit and Core.get("Security") == "Armed" and (Core.get("ArmMode") == "Away" or PERIMETER[room]) then
				Core.log("Motion detected: " .. room)
				Core.notify("Motion in " .. room .. "! Enter the code within " .. ENTRY_DELAY .. "s", "warn")
				countdown("Entry", ENTRY_DELAY, function() triggerAlarm("Intruder in " .. room) end)
			end
		end
		task.wait(0.2)
	end
end)

-- strobes
task.spawn(function()
	local on = false
	while true do
		on = (Core.get("Security") == "Alarm") and not on
		for _, s in strobes do
			s.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			s.Color = on and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(120, 30, 30)
			s:FindFirstChildOfClass("PointLight").Enabled = on
		end
		task.wait(0.25)
	end
end)

-- keypad (server side checks: proximity, rate limit, lockout, code)
local function atKeypad(player)
	for _, k in keypads do
		if Core.near(player, k, 12) then return true end
	end
	return false
end

remotes.Keypad.OnServerEvent:Connect(function(player, code, action)
	if typeof(code) ~= "string" or typeof(action) ~= "string" or #code > 8 then return end
	if not atKeypad(player) then return end
	local now = os.clock()
	if now - (lastKey[player] or 0) < 0.5 then return end
	lastKey[player] = now
	local function reply(msg, ok) remotes.Keypad:FireClient(player, "result", msg, ok) end

	if now < (lockedUntil[player] or 0) then
		reply("LOCKED OUT " .. math.ceil(lockedUntil[player] - now) .. "s", false)
		return
	end
	if code ~= Core.CODE then
		fails[player] = (fails[player] or 0) + 1
		failedTotal += 1
		Core.set("FailedLogins", failedTotal)
		Core.log("Wrong code from " .. player.Name .. " (" .. fails[player] .. "/" .. MAX_FAILS .. ")")
		if fails[player] >= MAX_FAILS then
			fails[player] = 0
			lockedUntil[player] = now + LOCKOUT
			Core.log("Keypad LOCKOUT: " .. player.Name)
			if Core.get("Security") ~= "Disarmed" then triggerAlarm("Brute force at keypad by " .. player.Name) end
			reply("LOCKED OUT " .. LOCKOUT .. "s", false)
		else
			reply("WRONG CODE", false)
		end
		return
	end

	fails[player] = 0
	local s = Core.get("Security")
	if action == "Disarm" then
		if s == "Disarmed" and not Core.get("Lockdown") then
			reply("ALREADY DISARMED", true)
		else
			disarm(player.Name)
			reply("DISARMED", true)
		end
	elseif action == "Away" or action == "Stay" then
		if s ~= "Disarmed" then
			reply("DISARM FIRST", false)
		else
			arm(action, player.Name)
			reply("ARMING " .. string.upper(action), true)
		end
	end
end)

-- control panel actions (allow-list + proximity + rate limit)
local ACTIONS = {
	lights_on = function() Core.call("lights_all", true) end,
	lights_off = function() Core.call("lights_all", false) end,
	party = function() Core.call("lights_party") end,
	garage = function(p) Core.call("garage_toggle", p.Name) end,
	door = function(p)
		if Core.get("DoorLocked") then
			if Core.get("Security") ~= "Disarmed" or Core.get("Lockdown") then
				Core.notify("Disarm the system to unlock the door", "warn", p)
				return
			end
			Core.call("door_lock", false, p.Name)
		else
			Core.call("door_lock", true, p.Name)
		end
	end,
	lockdown = function(p) lockdown(p.Name, false) end,
	day = function() Core.call("time_set", 12) end,
	night = function() Core.call("time_set", 21) end,
	cameras = function(p) remotes.Open:FireClient(p, "cameras") end,
	keypad = function(p) remotes.Open:FireClient(p, "keypad") end,
}

remotes.Panel.OnServerEvent:Connect(function(player, action)
	if typeof(action) ~= "string" then return end
	local fn = ACTIONS[action]
	if not fn then return end
	local close = false
	for _, cp in controlPoints do
		if Core.near(player, cp, 14) then close = true break end
	end
	if not close then return end
	local now = os.clock()
	if now - (lastPanel[player] or 0) < 0.3 then return end
	lastPanel[player] = now
	fn(player)
end)

Players.PlayerRemoving:Connect(function(p)
	fails[p], lockedUntil[p], lastKey[p], lastPanel[p] = nil, nil, nil, nil
end)

-- prompts
local function openFor(which) return function(p) remotes.Open:FireClient(p, which) end end
Core.prompt(sec:WaitForChild("OutsideKeypad"), "Use keypad", "Security", 0, 8).Triggered:Connect(openFor("keypad"))
Core.prompt(panel, "Control panel", "Smart Home", 0, 8).Triggered:Connect(openFor("panel"))
Core.prompt(secrets:WaitForChild("Monitor2"), "Security console", "Monitors", 0, 8).Triggered:Connect(openFor("panel"))
Core.prompt(console, "Cave console", "Console", 0, 8).Triggered:Connect(openFor("panel"))
Core.prompt(secrets:WaitForChild("PanicButton"), "PANIC", "Panic button", 1, 6).Triggered:Connect(function(p) lockdown(p.Name, true) end)

-- screens
local function label(parent, name, pos, size, text, ts, color, xa, font)
	local t = Instance.new("TextLabel")
	t.Name = name; t.Position = pos; t.Size = size; t.BackgroundTransparency = 1
	t.Text = text; t.TextSize = ts; t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Font = font or Enum.Font.GothamBold; t.TextXAlignment = xa or Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Top; t.TextWrapped = true; t.Parent = parent
	return t
end
local COLORS = { Disarmed = Color3.fromRGB(40, 220, 120), Arming = Color3.fromRGB(255, 170, 0), Armed = Color3.fromRGB(255, 60, 60),
	Entry = Color3.fromRGB(255, 170, 0), Alarm = Color3.fromRGB(255, 30, 30) }
local L = Enum.TextXAlignment.Left

local pbg = panel.Status.BG
label(pbg, "Title", UDim2.fromScale(0, 0.04), UDim2.fromScale(1, 0.14), "SMART HOME", 26, Color3.fromRGB(0, 180, 255))
local pState = label(pbg, "State", UDim2.fromScale(0, 0.2), UDim2.fromScale(1, 0.25), "", 42)
local pInfo = label(pbg, "Info", UDim2.fromScale(0.06, 0.5), UDim2.fromScale(0.88, 0.48), "", 20, Color3.fromRGB(200, 210, 220), L, Enum.Font.Gotham)

local kbg = sec.OutsideKeypad.Status.BG
local kState = label(kbg, "State", UDim2.fromScale(0, 0.15), UDim2.fromScale(1, 0.4), "", 18)
label(kbg, "Hint", UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.3), "PRESS E", 12, Color3.fromRGB(150, 160, 170))

local lbg = secrets.LogScreen.Screen.BG
label(lbg, "Title", UDim2.fromScale(0, 0.03), UDim2.fromScale(1, 0.1), "SECURITY LOG", 30, Color3.fromRGB(255, 80, 80))
local logText = label(lbg, "Lines", UDim2.fromScale(0.04, 0.15), UDim2.fromScale(0.92, 0.83), "", 18, Color3.fromRGB(120, 255, 160), L, Enum.Font.Code)

local nbg = secrets.NetworkScreen.Screen.BG
label(nbg, "Title", UDim2.fromScale(0, 0.04), UDim2.fromScale(1, 0.12), "NETWORK MONITOR", 26, Color3.fromRGB(0, 200, 255))
local netText = label(nbg, "Lines", UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.78), "", 18, Color3.fromRGB(120, 255, 160), L, Enum.Font.Code)

local camScreens = CS:GetTagged("CameraScreen")
local camParts = CS:GetTagged("CCTV")
table.sort(camParts, function(a, b) return a.Name < b.Name end)
for i, m in camScreens do
	local bg = m.Screen.BG
	local cam = camParts[i]
	label(bg, "Cam", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.3), cam and cam:GetAttribute("Label") or "CAM", 14, Color3.fromRGB(200, 220, 230), L, Enum.Font.Code)
	label(bg, "Live", UDim2.fromScale(0.05, 0.75), UDim2.fromScale(0.9, 0.2), "LIVE   PRESS E: VIEW", 11, Color3.fromRGB(255, 80, 80), L, Enum.Font.Code)
end

local caveScreen = cave:WaitForChild("GiantScreen").Screen.BG

local function stateText()
	local s = Core.get("Security")
	local cd = Core.get("Countdown")
	if s == "Arming" then return "ARMING " .. cd end
	if s == "Entry" then return "ENTER CODE " .. cd end
	if s == "Armed" then return "ARMED (" .. string.upper(Core.get("ArmMode")) .. ")" end
	if s == "Alarm" then return "ALARM" end
	if Core.get("Lockdown") then return "LOCKDOWN" end
	return "DISARMED"
end

local function refreshLog()
	logText.Text = table.concat(Core.LogLines, "\n")
	caveScreen.Log.Text = "EVENT LOG\n" .. table.concat(Core.LogLines, "\n", 1, math.min(#Core.LogLines, 8))
end
Core.LogChanged.Event:Connect(refreshLog)

local flash = false
while true do
	flash = not flash
	local s = Core.get("Security")
	local color = COLORS[s] or Color3.new(1, 1, 1)
	if Core.get("Lockdown") and s ~= "Alarm" then color = Color3.fromRGB(255, 120, 0) end
	if s == "Alarm" and flash then color = Color3.fromRGB(120, 0, 0) end
	local text = stateText()
	local door = Core.get("DoorLocked") and "Locked" or "Unlocked"
	pState.Text = text; pState.TextColor3 = color
	pInfo.Text = "Garage: " .. Core.get("Garage") .. "\nFront door: " .. door .. "\nTime: " .. Core.clock() .. "\nFailed logins: " .. Core.get("FailedLogins")
	kState.Text = text; kState.TextColor3 = color
	netText.Text = "ROUTER   10.0.0.1     ONLINE\nCAMERAS  x" .. #camParts .. "           ONLINE\nKEYPADS  x" .. #keypads .. "           ONLINE\nSENSORS  x" .. #CS:GetTagged("MotionSensor")
		.. "           ONLINE\nELEVATOR " .. string.upper(Core.get("Elevator") or "?") .. "\nFAILED LOGINS: " .. Core.get("FailedLogins") .. "\nALARM: " .. text
	caveScreen.Status.Text = "SECURITY   : " .. text .. "\nGARAGE     : " .. string.upper(Core.get("Garage")) .. "\nFRONT DOOR : " .. string.upper(door)
		.. "\nELEVATOR   : " .. string.upper(Core.get("Elevator") or "?") .. "\nTIME       : " .. Core.clock() .. "\nFAILED LOGINS: " .. Core.get("FailedLogins")
	caveScreen.Status.TextColor3 = (s == "Alarm") and color or Color3.fromRGB(120, 255, 160)
	task.wait(0.25)
end
