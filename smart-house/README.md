# Smart House (Roblox)

A raised, double-size modern smart house with an underground bat-cave, built for an IT and cyber security mentoring challenge. Every system is scripted and server-authoritative.

## What is in it

| System | What it does |
|---|---|
| **Lights** | Switch in every room, All On / All Off, Party Mode, a day/night cycle (one day is 8 minutes), garden and porch lights that switch on at dusk, a motion floodlight |
| **Garage** | A four-panel sectional door that rolls up a curved track onto the ceiling. Opens in 4 s, closes slowly in 9 s, status lamps (red, flashing orange, green), a safety beam that reverses the door if someone is underneath, auto-close after 45 s |
| **Security** | Keypads with Away and Stay arming, 15 s exit and entry delays, motion sensors in every room, sirens, strobes, a forced-door alarm, lockdown, a panic button, five CCTV cameras you can view, and a live security log |
| **Defences** | When the alarm goes off, every room fills with fire that burns intruders. The vault lasers kill intruders. Players who have entered a correct code are the owners and are never hurt. Guarded kill switches turn every trap off, and a purge button sets them all off on purpose |
| **Hidden ways in** | Pull the odd red book (bookcase to the security room), inspect the painting (attic ladder to the hidden server room), pull the clock's pendulum (secret elevator to the cave), tilt the bust's head (the fireplace slides away and a bat-pole drops you into the cave) |
| **The cave** | Reached by a ramp, the elevator or the bat-pole: a giant status screen, a car on a turntable, a suit display, a waterfall, a console, and a hand scanner that opens a hidden rock door |
| **The vault** | Behind the rock door: a moving laser corridor, then a round vault door with its own code. The four digits are on sticky notes hidden around the house. Inside: a giant coin, a giant card, a gadget wall, a bike and the flag |
| **Bat-signal** | A searchlight on the roof that throws the emblem into the sky, switched from the control panel |
| **Elevator** | A real physics elevator (PrismaticConstraint servo) with sliding landing doors at both levels |
| **Extras** | Doorbell, roof terrace with an automatic sliding door, rumpus room, upstairs lounge, master bedroom and study |

## Controls

Walk up to anything and press **E**. In the camera viewer, **Q** and **E** switch cameras and **X** exits. The keypad also takes the number keys.

## Security design (the cyber part)

The client never decides anything. It only sends requests, and the server checks each one:

- **The code lives on the server only.** It is a `ServerStorage` attribute (`AlarmCode`), so it is not in this repository and clients cannot read it. Keeping secrets out of source control is the first lesson.
- **Input validation.** Every remote checks the type and length of what it receives.
- **Proximity checks.** A keypad request only counts if the player is standing at a keypad. Control panel actions only count near a control point.
- **Allow-list.** The control panel accepts a fixed list of action names. Anything else is ignored.
- **Rate limiting and lockout.** Requests are throttled, and three wrong codes lock that player out for 30 s. Guessing while the system is armed trips the alarm.
- **Audit log.** Every arm, disarm, wrong code, forced door and secret door is written to the security log screen.
- **Fail closed.** When the alarm goes off, the garage closes and the front door locks.
- **Network ownership.** The server owns the elevator car, so a client cannot fling it.
- **Authentication and authorisation.** Entering a correct code proves you are an owner for the session. Owners are immune to the traps, and only owners can use the kill switches and the purge button.
- **Hidden information.** The vault code is split across four clues, like a capture-the-flag challenge.

Try to break it: brute force the keypad, fire the remotes from a script, or reach a hidden room without the trigger.

## Project layout

```
src/server/   ServerScriptService.SmartHouse (HouseCore module + one script per system)
src/client/   StarterPlayerScripts.SmartHouseClient (keypad, control panel, CCTV viewer, alerts)
```

`HouseCore` holds the shared state (attributes on the `SmartHouse` model), the log, and a small action registry so the scripts can call each other without hard links.

The scripts expect the `SmartHouse` model and the `SmartHouseRemotes` folder that are in the place file. This folder holds the code. The parts live in the place.

The house was built at scale 1 and scaled up with `Model:ScaleTo(2)`. Scripts read the model's `Scale` attribute and multiply their distances by it, so the house can be resized again.

## Setup

1. Open the place in Roblox Studio.
2. Set the codes: select **ServerStorage**, then under **Attributes** set `AlarmCode` and `VaultCode` (strings; the vault code must be 4 digits). If one is missing, the game picks a random code and prints it in the Output window. The vault clues always show the current vault code.
3. To sync code edits from this repo, use [Rojo](https://rojo.space) with `default.project.json`, or paste a file into the matching script.

## Sounds

Creator Store audio: siren `9114024708`, keypad beep `9117060548` (both Pro Sound Effects), doorbell chime `1414945022`, garage opener `105726030995683`.
