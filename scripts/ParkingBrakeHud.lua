-- Parking Brake Pro Edition (PropaineX)
-- Adds a BRAKE warning light to the speedometer, left of the gearbox icon: lit red while the
-- parking brake is on, dark while it is off. Its circle matches the gearbox icon's circle (20 px)
-- and sits level with it; the brackets need a 34 px section and the word BRAKE hangs below the row.
-- The game draws the icon sections right to left (fuel, repair, gear), 30 px apart, and stretches
-- the background by each section's width; this adds one more section after the gear.

local SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".parkingBrake"
local SYMBOL_FILENAME = Utils.getFilename("textures/parkingBrake_symbol.dds", g_currentModDirectory)
local TEXT_FILENAME = Utils.getFilename("textures/parkingBrake_text.dds", g_currentModDirectory)

-- the textures carry their own colors (red glow + hot center), so "on" is untinted.
-- When off the symbol goes dark and the word stays readable.
local COLOR_ON = {1, 1, 1, 1}
local SYMBOL_COLOR_OFF = {0.25, 0.25, 0.25, 1}
local TEXT_COLOR_OFF = {0.5, 0.5, 0.5, 1}

local function setupParkingBrakeIcon(display)
    if display.parkingBrakeSymbol == nil then
        display.parkingBrakeSymbol = Overlay.new(SYMBOL_FILENAME, 0, 0, 0, 0)
        display.parkingBrakeText = Overlay.new(TEXT_FILENAME, 0, 0, 0, 0)
    end

    -- both textures are 36 x 40 px and drawn on top of each other;
    -- the symbol centre is 18 px from the left and 15 px from the top
    local width, height = display:scalePixelValuesToScreenVector(36, 40)
    display.parkingBrakeSymbol:setDimension(width, height)
    display.parkingBrakeText:setDimension(width, height)
    display.parkingBrakeIconCenterX, display.parkingBrakeIconCenterY = display:scalePixelValuesToScreenVector(18, 25)
    display.parkingBrakeSectionWidth = display:scalePixelToScreenWidth(34)
end

-- reruns when the resolution or UI scale changes
SpeedMeterDisplay.storeScaledValues = Utils.appendedFunction(SpeedMeterDisplay.storeScaledValues, setupParkingBrakeIcon)

SpeedMeterDisplay.delete = Utils.prependedFunction(SpeedMeterDisplay.delete, function(self)
    if self.parkingBrakeSymbol ~= nil then
        self.parkingBrakeSymbol:delete()
        self.parkingBrakeSymbol = nil
        self.parkingBrakeText:delete()
        self.parkingBrakeText = nil
    end
end)

local function renderLightPart(overlay, color, x, y)
    overlay:setColor(color[1], color[2], color[3], color[4])
    overlay:setPosition(x, y)
    overlay:render()
end

SpeedMeterDisplay.draw = Utils.overwrittenFunction(SpeedMeterDisplay.draw, function(self, superFunc)
    local vehicle = self.vehicle
    if vehicle == nil or not self.isVehicleDrawSafe or vehicle[SPEC_TABLE_NAME] == nil then
        superFunc(self)
        return
    end

    -- the HUD may have stored its sizes before this mod was loaded
    if self.parkingBrakeSymbol == nil then
        setupParkingBrakeIcon(self)
    end

    -- gearBarScaleWidth is only used to size the background, so widen it for our section during the draw
    local gearBarScaleWidth = self.gearBarScaleWidth
    self.gearBarScaleWidth = gearBarScaleWidth + self.parkingBrakeSectionWidth
    superFunc(self)
    self.gearBarScaleWidth = gearBarScaleWidth

    -- overlay positions are bottom left; line the symbol centre up with the gearbox icon centre
    local gearCenterX = self.gearIcon.x + self.gearIcon.width * 0.5
    local gearCenterY = self.gearIcon.y + self.gearIcon.height * 0.5
    local x = gearCenterX - self.parkingBrakeSectionWidth - self.parkingBrakeIconCenterX
    local y = gearCenterY - self.parkingBrakeIconCenterY

    local isOn = vehicle:getIsParkingBrakeLightOn()
    renderLightPart(self.parkingBrakeSymbol, isOn and COLOR_ON or SYMBOL_COLOR_OFF, x, y)
    renderLightPart(self.parkingBrakeText, isOn and COLOR_ON or TEXT_COLOR_OFF, x, y)
end)
