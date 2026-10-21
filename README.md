# Parking Brake Pro Edition (FS25)

Farming Simulator 25 mod by PropaineX. Version 1.0.9.0.

Press backslash (`\`) in any drivable vehicle to put the parking brake on, and again to release it
(rebindable in the controls menu). While it is on, the vehicle holds with full brakes, the throttle does
nothing and cruise control is switched off. A BRAKE light on the speedometer shows when the parking brake
is on, or when the game, an AI helper or another mod holds the vehicle with the handbrake.
Saved with the vehicle, works in multiplayer, AI helpers are not held back by it.

## Files
- `modDesc.xml` - mod description, key binding, texts
- `scripts/ParkingBrakeRegister.lua` - adds the parking brake to every drivable vehicle type (not horses)
- `scripts/ParkingBrake.lua` - the parking brake itself, sync and save
- `scripts/ParkingBrakeHud.lua` - the BRAKE light on the speedometer
- `textures/` - the HUD light (symbol and word)
- `icon_ParkingBrake.dds` - shop icon

## Install
Zip the CONTENTS of this folder (modDesc.xml at the top of the zip, forward-slash paths) as
`FS25_ParkingBrake_ProEdition.zip` and put it in the FS25 `mods` folder. Don't rename the zip.

## License
MIT, see `LICENSE`.
