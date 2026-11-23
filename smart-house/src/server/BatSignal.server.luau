-- BatSignal: the searchlight on the roof. Switched from the control panel.
local Core = require(script.Parent:WaitForChild("HouseCore"))

local bs = Core.House:WaitForChild("BatSignal")
local beam = bs:WaitForChild("Beam")
local lens = bs:WaitForChild("Lens")
local spot = lens:WaitForChild("Spot")
local emblem = bs:WaitForChild("SkyEmblem"):WaitForChild("Emblem")

local function set(on)
	Core.set("BatSignal", on)
	beam.Transparency = on and 0.85 or 1
	emblem.Enabled = on
	spot.Enabled = on
	lens.Color = on and Color3.fromRGB(255, 245, 200) or Color3.fromRGB(90, 85, 70)
end

Core.register("batsignal", function(who)
	local on = not Core.get("BatSignal")
	set(on)
	Core.log("Bat-signal " .. (on and "ON" or "off") .. " by " .. who)
	if on then Core.notify("The signal is in the sky.", "info") end
end)

set(false)
