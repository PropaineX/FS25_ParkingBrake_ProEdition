-- Parking Brake Pro Edition (PropaineX)
-- Registers the parkingBrake specialization and adds it to every drivable vehicle type.

local modName = g_currentModName
local modDirectory = g_currentModDirectory

local SPEC_NAME = modName .. ".parkingBrake"

if g_specializationManager:getSpecializationByName("parkingBrake") == nil then
    g_specializationManager:addSpecialization("parkingBrake", "ParkingBrake", Utils.getFilename("scripts/ParkingBrake.lua", modDirectory), nil)
end

local function addParkingBrakeToVehicleTypes(typeManager)
    if typeManager.typeName ~= "vehicle" then
        return
    end

    local count = 0
    for typeName, typeEntry in pairs(typeManager.types) do
        local specs = typeEntry.specializations
        -- horses are drivable too, but a parking brake makes no sense on them
        local isHorse = Rideable ~= nil and SpecializationUtil.hasSpecialization(Rideable, specs)
        if SpecializationUtil.hasSpecialization(Drivable, specs) and not isHorse and typeEntry.specializationsByName[SPEC_NAME] == nil then
            typeManager:addSpecialization(typeName, SPEC_NAME)
            count = count + 1
        end
    end

    Logging.info("[ParkingBrake] Added parking brake to %d vehicle types", count)
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, addParkingBrakeToVehicleTypes)
