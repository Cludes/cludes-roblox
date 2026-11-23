# Smart House (Roblox)

A raised modern smart house with an underground garage cave, built for an IT and cyber security mentoring challenge. Every system is scripted and server-authoritative.

## What is in it

| System | What it does |
|---|---|
| **Lights** | Switch in every room, All On / All Off, Party Mode, a day/night cycle (one day is 8 minutes), garden and porch lights that switch on at dusk, a motion floodlight |
| **Garage** | A four-panel sectional door that rolls up a curved track onto the ceiling. Opens in 4 s, closes slowly in 9 s, status lamps (red, flashing orange, green), a safety beam that reverses the door if someone is underneath, auto-close after 45 s |
| **Security** | Keypads with Away and Stay arming, 15 s exit and entry delays, motion sensors in every room, sirens, strobes, a forced-door alarm, lockdown, a panic button, five CCTV cameras you can view, and a live security log |
| **Hidden rooms** | A bookcase that swings open when you pull the right book, a painting that drops an attic ladder into a hidden server room, and a grandfather clock that hides an elevator |
| **The cave** | An underground garage reached by a ramp or the secret elevator: a giant status screen, a car on a turntable, a suit display, a waterfall, and a console |
| **Elevator** | A real physics elevator (PrismaticConstraint servo) with sliding landing doors at both levels |
| **Extras** | Doorbell, roof terrace with an automatic sliding door, upstairs lounge, master bedroom and study |

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

Try to break it: brute force the keypad, fire the remotes from a script, or reach a hidden room without the trigger.

## Project layout

```
src/server/   ServerScriptService.SmartHouse (HouseCore module + one script per system)
src/client/   StarterPlayerScripts.SmartHouseClient (keypad, control panel, CCTV viewer, alerts)
```

`HouseCore` holds the shared state (attributes on the `SmartHouse` model), the log, and a small action registry so the scripts can call each other without hard links.

The scripts expect the `SmartHouse` model and the `SmartHouseRemotes` folder that are in the place file. This repo holds the code. The parts live in the place.

## Setup

1. Open the place in Roblox Studio.
2. Set the alarm code: select **ServerStorage**, then under **Attributes** set `AlarmCode` (a string, for example `4821`). If it is missing, the game picks a random code and prints it in the Output window.
3. To sync code edits from this repo, use [Rojo](https://rojo.space) with `default.project.json`, or paste a file into the matching script.

## Sounds

Creator Store audio: siren `9114024708`, keypad beep `9117060548` (both Pro Sound Effects), doorbell chime `1414945022`, garage opener `105726030995683`.
