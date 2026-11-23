# Garage Door (Command Bar)

A standalone garage you can drop into any place with no setup: a brick facade, a four-panel door with windows, status lamps, an interior light and buttons inside and out.

## Use it

1. Open a place in Roblox Studio.
2. Open the Command Bar (View > Command Bar).
3. Paste the whole of `GarageDoor.commandbar.luau` and press Enter.
4. Press Play, walk to the red button on the right of the door and hold E.

It builds at the origin, on top of a default Baseplate. Running it again replaces the earlier build.

## How it behaves

- Opens in 2.5 s and closes slowly in 8 s with smooth easing (`OPEN_TIME`, `CLOSE_TIME`).
- Lamps: red when closed, green when open, flashing orange while moving.
- If a player is in the doorway while it closes, it stops and reopens.
- Closes itself after 12 s (`AUTO_CLOSE`).
- Pressing a button while it is opening reverses it.

The full smart house in [`../smart-house`](../smart-house) uses a more advanced version of this door, with panels that roll up a curved track onto the ceiling.
