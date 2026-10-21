-- Parking Brake Pro Edition (PropaineX)
-- Backslash (default) turns the parking brake on and off. While it is on, the vehicle gets
-- no throttle and full brakes (the game's own handbrake path in WheelsUtil), and cruise
-- control is switched off. AI helpers are not held back by it.
-- The HUD light also comes on when anything else (game, AI helpers, other mods) holds the vehicle
-- with the handbrake: every such request passes WheelsUtil.updateWheelsPhysics on the server.

ParkingBrake = {}
ParkingBrake.MOD_NAME = g_currentModName
ParkingBrake.SPEC_NAME = g_currentModName .. ".parkingBrake"
ParkingBrake.SPEC_TABLE_NAME = "spec_" .. ParkingBrake.SPEC_NAME

-- the physics runs every frame; the light goes out this long after the last handbrake request
ParkingBrake.HANDBRAKE_TIMEOUT = 250

-- doHandbrake only brakes while there is no throttle (WheelsUtil automaticBrake), so only count it then
WheelsUtil.updateWheelsPhysics = Utils.prependedFunction(WheelsUtil.updateWheelsPhysics, function(vehicle, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking)
    local spec = vehicle[ParkingBrake.SPEC_TABLE_NAME]
    if spec ~= nil and doHandbrake and math.abs(acceleration) < 0.001 then
        spec.lastHandbrakeTime = g_time
    end
end)

function ParkingBrake.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations)
end

function ParkingBrake.initSpecialization()
    local schemaSavegame = Vehicle.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.BOOL, "vehicles.vehicle(?)." .. ParkingBrake.SPEC_NAME .. "#isOn", "Parking brake is on", false)
end

function ParkingBrake.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setParkingBrake", ParkingBrake.setParkingBrake)
    SpecializationUtil.registerFunction(vehicleType, "getIsParkingBrakeOn", ParkingBrake.getIsParkingBrakeOn)
    SpecializationUtil.registerFunction(vehicleType, "getIsParkingBrakeLightOn", ParkingBrake.getIsParkingBrakeLightOn)
end

function ParkingBrake.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", ParkingBrake.updateVehiclePhysics)
end

function ParkingBrake.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ParkingBrake)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ParkingBrake)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ParkingBrake)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ParkingBrake)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ParkingBrake)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ParkingBrake)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ParkingBrake)
end

function ParkingBrake:onLoad(savegame)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]

    spec.isOn = false
    spec.isHandbrakeActive = false
    spec.lastHandbrakeTime = nil
    spec.dirtyFlag = self:getNextDirtyFlag()
    spec.actionEvents = {}
    spec.texts = {
        apply = g_i18n:getText("action_parkingBrakeApply"),
        release = g_i18n:getText("action_parkingBrakeRelease"),
        warning = g_i18n:getText("warning_parkingBrakeOn")
    }

    if savegame ~= nil and not savegame.resetVehicles then
        spec.isOn = savegame.xmlFile:getValue(savegame.key .. "." .. ParkingBrake.SPEC_NAME .. "#isOn", false)
    end
end

function ParkingBrake:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]
    xmlFile:setValue(key .. "#isOn", spec.isOn)
end

function ParkingBrake:onReadStream(streamId, connection)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]
    spec.isOn = streamReadBool(streamId)
    spec.isHandbrakeActive = streamReadBool(streamId)
end

function ParkingBrake:onWriteStream(streamId, connection)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]
    streamWriteBool(streamId, spec.isOn)
    streamWriteBool(streamId, spec.isHandbrakeActive)
end

-- handbrake state goes from the server to the clients only
function ParkingBrake:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self[ParkingBrake.SPEC_TABLE_NAME]
        if streamReadBool(streamId) then
            spec.isHandbrakeActive = streamReadBool(streamId)
        end
    end
end

function ParkingBrake:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self[ParkingBrake.SPEC_TABLE_NAME]
        if streamWriteBool(streamId, bit32.band(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteBool(streamId, spec.isHandbrakeActive)
        end
    end
end

function ParkingBrake:getIsParkingBrakeOn()
    return self[ParkingBrake.SPEC_TABLE_NAME].isOn
end

-- the HUD light: our parking brake, or a handbrake applied by anything else
function ParkingBrake:getIsParkingBrakeLightOn()
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]
    return spec.isOn or spec.isHandbrakeActive
end

function ParkingBrake:setParkingBrake(isOn, noEventSend)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]
    if isOn == spec.isOn then
        return
    end

    spec.isOn = isOn
    ParkingBrakeEvent.sendEvent(self, isOn, noEventSend)
    ParkingBrake.updateActionText(self)
end

function ParkingBrake:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]
    if spec.isOn and not self:getIsAIActive() then
        -- cruise control forces full throttle in Drivable.updateVehiclePhysics
        if self:getCruiseControlState() ~= Drivable.CRUISECONTROL_STATE_OFF then
            self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_OFF)
        end

        -- no throttle + handbrake = brake pedal 1 (WheelsUtil.updateWheelsPhysics)
        return superFunc(self, 0, axisSide, true, dt)
    end

    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end

function ParkingBrake:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[ParkingBrake.SPEC_TABLE_NAME]

    if self.isServer then
        local isHandbrakeActive = spec.lastHandbrakeTime ~= nil and g_time - spec.lastHandbrakeTime < ParkingBrake.HANDBRAKE_TIMEOUT
        if isHandbrakeActive ~= spec.isHandbrakeActive then
            spec.isHandbrakeActive = isHandbrakeActive
            self:raiseDirtyFlags(spec.dirtyFlag)
        end
    end

    -- tell the driver why the vehicle won't move
    if spec.isOn and self.isClient and isActiveForInputIgnoreSelection and not self:getIsAIActive() then
        if math.abs(self.spec_drivable.axisForward) > 0.05 then
            g_currentMission:showBlinkingWarning(spec.texts.warning, 500)
        end
    end
end

function ParkingBrake:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self[ParkingBrake.SPEC_TABLE_NAME]
        self:clearActionEventsTable(spec.actionEvents)

        local entered = true
        if self.getIsEntered ~= nil then
            entered = self:getIsEntered()
        end

        if isActiveForInputIgnoreSelection and entered then
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.PARKING_BRAKE_TOGGLE, self, ParkingBrake.actionEventToggle, false, true, false, true, nil)
            spec.actionEventId = actionEventId
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            ParkingBrake.updateActionText(self)
        end
    end
end

function ParkingBrake.actionEventToggle(self, actionName, inputValue, callbackState, isAnalog)
    self:setParkingBrake(not self:getIsParkingBrakeOn())
end

function ParkingBrake.updateActionText(vehicle)
    local spec = vehicle[ParkingBrake.SPEC_TABLE_NAME]
    if spec.actionEventId ~= nil then
        local text = spec.isOn and spec.texts.release or spec.texts.apply
        g_inputBinding:setActionEventText(spec.actionEventId, text)
    end
end


-- Syncs the parking brake between server and clients.
ParkingBrakeEvent = {}
local ParkingBrakeEvent_mt = Class(ParkingBrakeEvent, Event)
InitEventClass(ParkingBrakeEvent, "ParkingBrakeEvent")

function ParkingBrakeEvent.emptyNew()
    return Event.new(ParkingBrakeEvent_mt)
end

function ParkingBrakeEvent.new(vehicle, isOn)
    local self = ParkingBrakeEvent.emptyNew()
    self.vehicle = vehicle
    self.isOn = isOn
    return self
end

function ParkingBrakeEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isOn = streamReadBool(streamId)
    self:run(connection)
end

function ParkingBrakeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isOn)
end

function ParkingBrakeEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setParkingBrake(self.isOn, true)
    end
end

function ParkingBrakeEvent.sendEvent(vehicle, isOn, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ParkingBrakeEvent.new(vehicle, isOn), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(ParkingBrakeEvent.new(vehicle, isOn))
        end
    end
end
