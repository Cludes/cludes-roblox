-- Vault: the cave's east wing. A hand scanner opens the rock door, a laser corridor guards
-- the round vault door, and the vault code is split into clues hidden around the house.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Core = require(script.Parent:WaitForChild("HouseCore"))

local S = Core.S
local house = Core.House
local wing = house:WaitForChild("CaveWing")
local lasers = wing:WaitForChild("Lasers")
local start = wing:WaitForChild("LaserStart")

-- vault code: a ServerStorage attribute, like the alarm code
local CODE = game:GetService("ServerStorage"):GetAttribute("VaultCode")
if typeof(CODE) ~= "string" or #CODE ~= 4 then
	CODE = tostring(math.random(1000, 9999))
	warn("[SmartHouse] No 4-digit VaultCode attribute on ServerStorage. Using random code " .. CODE)
end
Core.VAULT_CODE = CODE

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), props):Play()
end

-- drive a part (and everything inside it) from a NumberValue through apply(baseCFrame, value)
local function driver(part, apply)
	local base = part.CFrame
	local decor = {}
	for _, c in part:GetDescendants() do
		if c:IsA("BasePart") then table.insert(decor, { part = c, offset = base:ToObjectSpace(c.CFrame) }) end
	end
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(x)
		local cf = apply(base, x)
		part.CFrame = cf
		for _, d in decor do d.part.CFrame = cf * d.offset end
	end)
	return v
end

---------------- rock door ----------------
local rockDoor = wing:WaitForChild("RockDoor")
local drop = rockDoor.Size.Y + 0.2 * S
local rockV = driver(rockDoor, function(base, t) return base - Vector3.new(0, drop * t, 0) end)
local rockOpen, rockToken = false, 0
local function setRock(open, who)
	if rockOpen == open then return end
	rockOpen = open
	rockToken += 1
	tween(rockV, { Value = open and 1 or 0 }, 1.8)
	if open then
		if who then Core.log("Rock door opened by " .. who) end
		local my = rockToken
		task.delay(15, function() if rockToken == my then setRock(false) end end)
	end
end
local scanner = wing:WaitForChild("HandScanner")
Core.prompt(scanner, "Scan hand", "Scanner", 1, 6).Triggered:Connect(function(p)
	local glow = scanner:FindFirstChild("Glow")
	if glow then
		glow.Color = Color3.fromRGB(40, 255, 80)
		task.delay(1.5, function() glow.Color = Color3.fromRGB(0, 170, 255) end)
	end
	setRock(true, p.Name)
end)
Core.prompt(wing:WaitForChild("ExitScanner"), "Scan hand", "Scanner", 1, 6).Triggered:Connect(function(p) setRock(true, p.Name) end)

---------------- vault door (turns around its hinge) ----------------
local hinge = wing:WaitForChild("VaultHinge").CFrame
local vaultDoor = wing:WaitForChild("VaultDoor")
local rel = hinge:ToObjectSpace(vaultDoor.CFrame)
local angle = driver(vaultDoor, function(_, a) return hinge * CFrame.Angles(0, math.rad(a), 0) * rel end)
local vaultOpen, vaultToken = false, 0
local function setVault(open, who)
	if vaultOpen == open then return end
	vaultOpen = open
	vaultToken += 1
	tween(angle, { Value = open and -100 or 0 }, 2.5)
	Core.set("VaultOpen", open)
	if open then
		Core.log("VAULT opened by " .. (who or "?"))
		Core.notify("Vault unlocked", "ok")
		local my = vaultToken
		task.delay(25, function() if vaultToken == my then setVault(false) end end)
	end
end
Core.register("vault_open", function(who) setVault(true, who) end)
Core.prompt(wing:WaitForChild("VaultKeypad"), "Enter code", "Vault", 0, 6).Triggered:Connect(function(p)
	Core.Remotes.Open:FireClient(p, "vault")
end)
Core.prompt(wing:WaitForChild("VaultExit"), "Open vault door", "Vault", 0, 6).Triggered:Connect(function(p) setVault(true, p.Name) end)

---------------- lasers ----------------
-- Lethal mode (Defences on) kills intruders; otherwise a hit sends them back to the start.
Core.set("Lasers", true)
local beams = {}
for _, b in lasers:GetChildren() do table.insert(beams, { part = b, y = b.Position.Y, phase = b:GetAttribute("Phase") }) end
local lastHit = {}
local function setLasers(on, who)
	Core.set("Lasers", on)
	for _, b in beams do b.part.Transparency = on and 0 or 1 end
	if who then Core.log("Lasers " .. (on and "ARMED" or "disabled") .. " by " .. who) end
end
Core.register("lasers_toggle", function(who) setLasers(not Core.get("Lasers"), who) end)
Core.prompt(wing:WaitForChild("VaultExitPost"), "Toggle lasers", "Laser grid", 0, 6).Triggered:Connect(function(p) setLasers(not Core.get("Lasers"), p.Name) end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, b in beams do
		local p = b.part.Position
		b.part.Position = Vector3.new(p.X, b.y + 2.6 * S * math.sin(t * 1.6 + b.phase), p.Z)
	end
end)

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
task.spawn(function()
	while true do
		if Core.get("Lasers") then
			local chars = {}
			for _, plr in Players:GetPlayers() do
				if plr.Character then table.insert(chars, plr.Character) end
			end
			params.FilterDescendantsInstances = chars
			for _, b in beams do
				for _, hit in workspace:GetPartsInPart(b.part, params) do
					local plr = Players:GetPlayerFromCharacter(hit:FindFirstAncestorOfClass("Model"))
					if plr and os.clock() - (lastHit[plr] or 0) > 1.5 then
						lastHit[plr] = os.clock()
						Core.log("Laser tripwire hit by " .. plr.Name)
						if Core.lethal(plr) then
							local hum = plr.Character:FindFirstChildOfClass("Humanoid")
							if hum then hum.Health = 0 end
							Core.notify("Vaporised by the laser grid.", "alarm", plr)
						else
							plr.Character:PivotTo(start.CFrame)
							Core.notify("Laser tripped! Back to the start.", "warn", plr)
						end
						Core.call("security_breach", "Laser tripwire hit by " .. plr.Name)
					end
				end
			end
		end
		task.wait(0.05)
	end
end)
Players.PlayerRemoving:Connect(function(p) lastHit[p] = nil end)

---------------- clues: one digit of the vault code in each hidden place ----------------
for i, spot in { "ClueOffice", "ClueSafe", "ClueServer", "ClueCave" } do
	local part = house:WaitForChild("Clues"):WaitForChild(spot)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId[part:GetAttribute("Face") or "Front"]
	sg.LightInfluence = 0.3
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 235, 120)
	t.BorderSizePixel = 0
	t.Font = Enum.Font.PermanentMarker
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(30, 30, 30)
	t.Text = "VAULT PIN\ndigit " .. i .. " = " .. CODE:sub(i, i)
	t.Parent = sg
end

---------------- fireplace flicker ----------------
local fire = house:WaitForChild("Rumpus"):WaitForChild("Fireplace"):WaitForChild("Fire")
local fireLight = fire:WaitForChild("FireLight")
while true do
	fireLight.Brightness = 1.6 + math.random() * 0.9
	fire.Color = Color3.fromRGB(255, 100 + math.random(0, 50), 20)
	task.wait(0.12)
end
