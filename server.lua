local ESX = exports['es_extended']:getSharedObject()
local PlayerDataCache = {}
local ActivityCache = {}
local triggerConfiguredEvent

local function getIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier or nil
end

local function xpRequiredForLevel(level)
    return Config.Leveling.BaseXP + ((level - 1) * Config.Leveling.GrowthPerLevel)
end

local function calculateLevelProgress(totalXP)
    local level = 1
    local remainingXP = totalXP

    -- Każdy kolejny poziom kosztuje więcej XP zgodnie z konfiguracją.
    while remainingXP >= xpRequiredForLevel(level) do
        remainingXP = remainingXP - xpRequiredForLevel(level)
        level = level + 1
    end

    return level
end

local function normalizeSkillMap(skills)
    if type(skills) ~= 'table' then
        return {}
    end

    local normalized = {}
    for skillId, unlocked in pairs(skills) do
        if Config.Skills[skillId] and unlocked then
            normalized[skillId] = true
        end
    end

    return normalized
end

local function savePlayerData(identifier, data)
    if not identifier or not data then
        return
    end

    MySQL.update.await([[
        INSERT INTO horizon_skill_tree (identifier, xp, level, skill_points, skills)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            xp = VALUES(xp),
            level = VALUES(level),
            skill_points = VALUES(skill_points),
            skills = VALUES(skills)
    ]], {
        identifier,
        data.xp,
        data.level,
        data.skillPoints,
        json.encode(data.skills)
    })
end

local function getOrCreatePlayerData(source)
    local identifier = getIdentifier(source)
    if not identifier then
        return nil, nil
    end

    if PlayerDataCache[source] then
        return PlayerDataCache[source], identifier
    end

    local row = MySQL.single.await(
        'SELECT xp, level, skill_points, skills FROM horizon_skill_tree WHERE identifier = ?',
        { identifier }
    )

    local data = {
        xp = 0,
        level = 1,
        skillPoints = 0,
        skills = {}
    }

    if row then
        data.xp = tonumber(row.xp) or 0
        data.level = tonumber(row.level) or 1
        data.skillPoints = tonumber(row.skill_points) or 0
        data.skills = normalizeSkillMap(json.decode(row.skills or '{}'))
    else
        savePlayerData(identifier, data)
    end

    PlayerDataCache[source] = data
    return data, identifier
end

local function syncPlayerData(source)
    local data = PlayerDataCache[source]
    if not data then
        return
    end

    TriggerClientEvent('horizon_skill_tree:client:updateData', source, data)
end

local function hasSkill(source, skillId)
    local data = PlayerDataCache[source] or getOrCreatePlayerData(source)
    return data and data.skills[skillId] == true or false
end

local function addXP(source, amount)
    amount = tonumber(amount)
    if not amount or amount == 0 then
        return false
    end

    local data, identifier = getOrCreatePlayerData(source)
    if not data then
        return false
    end

    data.xp = math.max(0, data.xp + math.floor(amount))

    local previousLevel = data.level
    local newLevel = calculateLevelProgress(data.xp)

    if newLevel > previousLevel then
        local gainedLevels = newLevel - previousLevel
        data.skillPoints = data.skillPoints + (gainedLevels * Config.Leveling.SkillPointsPerLevel)
        data.level = newLevel

        TriggerClientEvent('esx:showNotification', source,
            ('Awans! Osiągnięto poziom %s i otrzymano %s punkt(ów) umiejętności.')
            :format(newLevel, gainedLevels * Config.Leveling.SkillPointsPerLevel)
        )

        if Config.Triggers then
            triggerConfiguredEvent(Config.Triggers.OnLevelUpServer, source, newLevel, data)
        end
    else
        data.level = newLevel
    end

    savePlayerData(identifier, data)
    syncPlayerData(source)

    return true
end

local function addSkillPoints(source, amount)
    amount = tonumber(amount)
    if not amount then
        return false
    end

    local data, identifier = getOrCreatePlayerData(source)
    if not data then
        return false
    end

    data.skillPoints = math.max(0, data.skillPoints + math.floor(amount))
    savePlayerData(identifier, data)
    syncPlayerData(source)

    return true
end

triggerConfiguredEvent = function(eventName, ...)
    if type(eventName) ~= 'string' or eventName == '' then
        return
    end

    TriggerEvent(eventName, ...)
end

local function buildCombatModifiers(skills)
    local weaponBonus, meleeBonus, recoilReduction = 0.0, 0.0, 0.0
    if not Config.Combat or not Config.Combat.Enabled then
        return weaponBonus, meleeBonus, recoilReduction
    end

    if type(skills) ~= 'table' then
        return weaponBonus, meleeBonus, recoilReduction
    end

    for skillId, unlocked in pairs(skills) do
        if unlocked and Config.Skills[skillId] then
            local combat = Config.Skills[skillId].effects and Config.Skills[skillId].effects.combat
            if combat then
                weaponBonus = weaponBonus + (tonumber(combat.weaponDamage) or 0.0)
                meleeBonus = meleeBonus + (tonumber(combat.meleeDamage) or 0.0)
                recoilReduction = recoilReduction + (tonumber(combat.recoilReduction) or 0.0)
            end
        end
    end

    weaponBonus = math.min(weaponBonus, tonumber(Config.Combat.MaxWeaponBonus) or 0.0)
    meleeBonus = math.min(meleeBonus, tonumber(Config.Combat.MaxMeleeBonus) or 0.0)
    recoilReduction = math.min(math.max(0.0, recoilReduction), tonumber(Config.Combat.MaxRecoilReduction) or 0.0)

    return weaponBonus, meleeBonus, recoilReduction
end

local function buildNativeModifiers(skills)
    local sprintBonus, staminaBonus, underwaterTimeBonus, vehicleDamageReduction = 0.0, 0.0, 0.0, 0.0
    if type(skills) ~= 'table' then
        return sprintBonus, staminaBonus, underwaterTimeBonus, vehicleDamageReduction
    end

    for skillId, unlocked in pairs(skills) do
        if unlocked and Config.Skills[skillId] then
            local effects = Config.Skills[skillId].effects
            local movement = effects and effects.movement
            local underwater = effects and effects.underwater
            local driving = effects and effects.driving

            if movement then
                sprintBonus = sprintBonus + (tonumber(movement.sprintBonus) or 0.0)
                staminaBonus = staminaBonus + (tonumber(movement.staminaBonus) or 0.0)
            end
            if underwater then
                underwaterTimeBonus = underwaterTimeBonus + (tonumber(underwater.maxTimeBonus) or 0.0)
            end
            if driving then
                vehicleDamageReduction = vehicleDamageReduction + (tonumber(driving.vehicleDamageReduction) or 0.0)
            end
        end
    end

    if Config.Native and Config.Native.Movement and Config.Native.Movement.Enabled then
        sprintBonus = math.min(math.max(0.0, sprintBonus), tonumber(Config.Native.Movement.MaxSprintBonus) or 0.0)
        staminaBonus = math.min(math.max(0.0, staminaBonus), tonumber(Config.Native.Movement.MaxStaminaBonus) or 0.0)
    else
        sprintBonus = 0.0
        staminaBonus = 0.0
    end

    if Config.Native and Config.Native.Underwater and Config.Native.Underwater.Enabled then
        underwaterTimeBonus = math.min(
            math.max(0.0, underwaterTimeBonus),
            tonumber(Config.Native.Underwater.MaxTimeBonus) or 0.0
        )
    else
        underwaterTimeBonus = 0.0
    end

    if Config.Native and Config.Native.Driving and Config.Native.Driving.Enabled then
        vehicleDamageReduction = math.min(
            math.max(0.0, vehicleDamageReduction),
            tonumber(Config.Native.Driving.MaxDamageReduction) or 0.0
        )
    else
        vehicleDamageReduction = 0.0
    end

    return sprintBonus, staminaBonus, underwaterTimeBonus, vehicleDamageReduction
end

local function getFishingIntegrationConfig()
    return Config.Integrations and Config.Integrations.Fishing or nil
end

local function buildFishingModifiers(skills)
    local integration = getFishingIntegrationConfig()
    local defaults = integration and integration.Defaults or {}
    local limits = integration and integration.Limits or {}

    local xpMultiplier = tonumber(defaults.xpMultiplier) or 1.0
    local rareChanceMultiplier = tonumber(defaults.rareChanceMultiplier) or 1.0

    if type(skills) ~= 'table' then
        return {
            xpMultiplier = math.max(0.0, xpMultiplier),
            rareChanceMultiplier = math.max(0.0, rareChanceMultiplier)
        }
    end

    for skillId, unlocked in pairs(skills) do
        if unlocked and Config.Skills[skillId] then
            local fishing = Config.Skills[skillId].effects and Config.Skills[skillId].effects.fishing
            if fishing then
                local xpMod = tonumber(fishing.xpMultiplier)
                local rareMod = tonumber(fishing.rareChanceMultiplier)

                if xpMod and xpMod > 0 then
                    xpMultiplier = xpMultiplier * xpMod
                end
                if rareMod and rareMod > 0 then
                    rareChanceMultiplier = rareChanceMultiplier * rareMod
                end
            end
        end
    end

    local maxXP = tonumber(limits.MaxXPMultiplier)
    if maxXP then
        xpMultiplier = math.min(xpMultiplier, maxXP)
    end

    local maxRare = tonumber(limits.MaxRareChanceMultiplier)
    if maxRare then
        rareChanceMultiplier = math.min(rareChanceMultiplier, maxRare)
    end

    return {
        xpMultiplier = math.max(0.0, xpMultiplier),
        rareChanceMultiplier = math.max(0.0, rareChanceMultiplier)
    }
end

local function getFishingModifiers(source)
    local data = PlayerDataCache[source] or getOrCreatePlayerData(source)
    if not data then
        return buildFishingModifiers(nil)
    end

    return buildFishingModifiers(data.skills)
end

local function calculateFishingXP(source, catchData)
    local integration = getFishingIntegrationConfig()
    if not integration or not integration.Enabled then
        return 0
    end

    catchData = type(catchData) == 'table' and catchData or {}
    local xpConfig = integration.XP or {}
    local rarityBonusMap = xpConfig.RarityBonus or {}
    local security = integration.Security or {}

    local baseXP = tonumber(xpConfig.BasePerCatch) or 0
    local rarity = tostring(catchData.rarity or ''):lower()
    local rarityBonus = 0
    local hasKnownRarity = rarity ~= '' and rarityBonusMap[rarity] ~= nil

    if security.RequireKnownRarity and not hasKnownRarity then
        return 0
    end

    if hasKnownRarity then
        rarityBonus = tonumber(rarityBonusMap[rarity]) or 0
    end

    local modifiers = getFishingModifiers(source)
    local totalXP = (baseXP + rarityBonus) * ((modifiers and modifiers.xpMultiplier) or 1.0)

    local maxPerCatch = tonumber(xpConfig.MaxPerCatch)
    if maxPerCatch then
        totalXP = math.min(totalXP, maxPerCatch)
    end

    return math.max(0, math.floor(totalXP))
end

local function awardFishingXP(source, catchData)
    local xp = calculateFishingXP(source, catchData)
    if xp <= 0 then
        return false, 0
    end

    return addXP(source, xp), xp
end

local function isAllowedBridgeResource(resourceName)
    local integration = getFishingIntegrationConfig()
    local allowed = integration and integration.Security and integration.Security.AllowedBridgeResources
    if type(allowed) ~= 'table' or #allowed == 0 then
        return false
    end

    if type(resourceName) ~= 'string' or resourceName == '' then
        return false
    end

    for _, allowedName in ipairs(allowed) do
        if allowedName == resourceName then
            return true
        end
    end

    return false
end

local function resetPlayerProgress(source)
    local data, identifier = getOrCreatePlayerData(source)
    if not data then
        return false
    end

    data.xp = 0
    data.level = 1
    data.skillPoints = 0
    data.skills = {}

    savePlayerData(identifier, data)
    syncPlayerData(source)
    TriggerClientEvent('horizon_skill_tree:client:requestCombatSync', source)

    return true
end

local function isAdminSource(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    local allowed = Config.Admin and Config.Admin.AllowedGroups
    if type(allowed) ~= 'table' or #allowed == 0 then
        return false
    end

    local group = type(xPlayer.getGroup) == 'function' and xPlayer.getGroup() or nil
    if type(group) ~= 'string' then
        return false
    end

    for _, allowedGroup in ipairs(allowed) do
        if allowedGroup == group then
            return true
        end
    end

    return false
end

local function resolveTargetSource(adminSource, value)
    if value == 'me' then
        return adminSource
    end

    local target = tonumber(value)
    if not target then
        return nil
    end

    return GetPlayerName(target) and target or nil
end

local function tryPurchaseSkill(source, skillId)
    local skill = Config.Skills[skillId]
    if not skill then
        return false, 'Nie znaleziono umiejętności.'
    end

    local data, identifier = getOrCreatePlayerData(source)
    if not data then
        return false, 'Brak danych gracza.'
    end

    if data.skills[skillId] then
        return false, 'Ta umiejętność jest już odblokowana.'
    end

    if skill.requirement and not data.skills[skill.requirement] then
        return false, 'Najpierw odblokuj poprzednią umiejętność.'
    end

    if data.skillPoints < skill.cost then
        return false, 'Brak punktów umiejętności.'
    end

    data.skillPoints = data.skillPoints - skill.cost
    data.skills[skillId] = true

    savePlayerData(identifier, data)
    syncPlayerData(source)

    if type(skill.triggers) == 'table' then
        triggerConfiguredEvent(skill.triggers.server, source, skillId, skill)
        if type(skill.triggers.client) == 'string' and skill.triggers.client ~= '' then
            TriggerClientEvent(skill.triggers.client, source, skillId, skill)
        end
    end

    if Config.Triggers then
        triggerConfiguredEvent(Config.Triggers.OnSkillUnlockServer, source, skillId, skill)
        if type(Config.Triggers.OnSkillUnlockClient) == 'string' and Config.Triggers.OnSkillUnlockClient ~= '' then
            TriggerClientEvent(Config.Triggers.OnSkillUnlockClient, source, skillId, skill)
        end
    end

    TriggerClientEvent('horizon_skill_tree:client:requestCombatSync', source)

    return true, 'Odblokowano umiejętność: ' .. skill.name
end

RegisterNetEvent('horizon_skill_tree:server:requestData', function()
    local source = source
    local data = getOrCreatePlayerData(source)
    if not data then
        return
    end

    TriggerClientEvent('horizon_skill_tree:client:open', source, {
        player = data,
        skills = Config.Skills
    })
end)

RegisterNetEvent('horizon_skill_tree:server:purchaseSkill', function(skillId)
    local source = source
    local success, message = tryPurchaseSkill(source, skillId)
    TriggerClientEvent('horizon_skill_tree:client:purchaseResult', source, success, message)
end)

RegisterNetEvent('horizon_skill_tree:server:addXP', function(amount)
    if not Config.Security or Config.Security.AllowClientAddXPEvent ~= true then
        return
    end

    addXP(source, amount)
end)

RegisterNetEvent('horizon_skill_tree:server:addSkillPoints', function(amount)
    if not Config.Security or Config.Security.AllowClientSkillPointEvents ~= true then
        return
    end

    addSkillPoints(source, amount)
end)

RegisterNetEvent('horizon_skill_tree:server:removeSkillPoints', function(amount)
    if not Config.Security or Config.Security.AllowClientSkillPointEvents ~= true then
        return
    end

    addSkillPoints(source, -(tonumber(amount) or 0))
end)

exports('AddXP', addXP)
exports('RemoveXP', function(source, amount)
    return addXP(source, -(tonumber(amount) or 0))
end)
exports('AddSkillPoints', addSkillPoints)
exports('RemoveSkillPoints', function(source, amount)
    return addSkillPoints(source, -(tonumber(amount) or 0))
end)
exports('HasSkill', hasSkill)
exports('GetFishingModifiers', getFishingModifiers)
exports('GetFishingXPForCatch', calculateFishingXP)
exports('AwardFishingXP', awardFishingXP)

RegisterNetEvent((Config.Triggers and Config.Triggers.SyncCombatServer) or 'horizon_skill_tree:server:syncCombat', function()
    local source = source
    local data = PlayerDataCache[source] or getOrCreatePlayerData(source)
    if not data then
        return
    end

    local weaponBonus, meleeBonus, recoilReduction = buildCombatModifiers(data.skills)
    local sprintBonus, staminaBonus, underwaterTimeBonus, vehicleDamageReduction = buildNativeModifiers(data.skills)

    TriggerClientEvent('horizon_skill_tree:client:applyCombat', source, {
        weapon = weaponBonus,
        melee = meleeBonus,
        recoilReduction = recoilReduction,
        sprintBonus = sprintBonus,
        staminaBonus = staminaBonus,
        underwaterTimeBonus = underwaterTimeBonus,
        vehicleDamageReduction = vehicleDamageReduction
    })
end)

RegisterCommand((Config.Admin and Config.Admin.Command) or 'skilladmin', function(source, args)
    if source == 0 then
        print('[horizon-skill-tree] Komenda dostępna tylko dla graczy in-game.')
        return
    end

    if not isAdminSource(source) then
        TriggerClientEvent('esx:showNotification', source, 'Brak uprawnień do użycia tej komendy.')
        return
    end

    local targetSource = resolveTargetSource(source, tostring(args[1] or ''))
    local action = tostring(args[2] or ''):lower()
    local amount = tonumber(args[3] or 0)

    if not targetSource or action == '' then
        TriggerClientEvent('esx:showNotification', source,
            ('Użycie: /%s <id|me> <addxp|addsp|reset> [amount]')
            :format((Config.Admin and Config.Admin.Command) or 'skilladmin'))
        return
    end

    if action == 'addxp' then
        if not amount or amount == 0 then
            TriggerClientEvent('esx:showNotification', source, 'Podaj poprawną ilość XP.')
            return
        end

        addXP(targetSource, amount)
        TriggerClientEvent('esx:showNotification', source, ('Dodano %s XP dla ID %s.'):format(math.floor(amount), targetSource))
        TriggerClientEvent('esx:showNotification', targetSource,
            ('Administrator dodał Ci %s XP.'):format(math.floor(amount)))
        return
    end

    if action == 'addsp' then
        if not amount or amount == 0 then
            TriggerClientEvent('esx:showNotification', source, 'Podaj poprawną ilość punktów.')
            return
        end

        addSkillPoints(targetSource, amount)
        TriggerClientEvent('esx:showNotification', source,
            ('Dodano %s punkt(ów) umiejętności dla ID %s.'):format(math.floor(amount), targetSource))
        TriggerClientEvent('esx:showNotification', targetSource,
            ('Administrator dodał Ci %s punkt(ów) umiejętności.'):format(math.floor(amount)))
        return
    end

    if action == 'reset' then
        if not resetPlayerProgress(targetSource) then
            TriggerClientEvent('esx:showNotification', source, 'Nie udało się zresetować postępu.')
            return
        end

        TriggerClientEvent('esx:showNotification', source, ('Zresetowano postęp gracza ID %s.'):format(targetSource))
        TriggerClientEvent('esx:showNotification', targetSource, 'Administrator zresetował Twój postęp skilli.')
        return
    end

    TriggerClientEvent('esx:showNotification', source, 'Dostępne akcje: addxp, addsp, reset.')
end, false)

local fishingIntegrationEvent = getFishingIntegrationConfig()
fishingIntegrationEvent = fishingIntegrationEvent and fishingIntegrationEvent.Events and fishingIntegrationEvent.Events.CatchReportedServer

if type(fishingIntegrationEvent) == 'string' and fishingIntegrationEvent ~= '' then
    AddEventHandler(fishingIntegrationEvent, function(targetSource, catchData)
        local invokingResource = GetInvokingResource()
        if not isAllowedBridgeResource(invokingResource) then
            print(('[horizon-skill-tree] Zablokowano fishing bridge z nieautoryzowanego zasobu: %s')
                :format(invokingResource or 'unknown'))
            return
        end

        local source = tonumber(targetSource)
        if not source then
            return
        end

        awardFishingXP(source, catchData)
    end)
end

AddEventHandler('playerDropped', function()
    local source = source
    local data = PlayerDataCache[source]
    if not data then
        return
    end

    local identifier = getIdentifier(source)
    savePlayerData(identifier, data)
    PlayerDataCache[source] = nil
    ActivityCache[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for source, data in pairs(PlayerDataCache) do
        local identifier = getIdentifier(source)
        savePlayerData(identifier, data)
    end
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS horizon_skill_tree (
            identifier VARCHAR(80) NOT NULL,
            xp INT NOT NULL DEFAULT 0,
            level INT NOT NULL DEFAULT 1,
            skill_points INT NOT NULL DEFAULT 0,
            skills LONGTEXT NULL,
            PRIMARY KEY (identifier)
        )
    ]])
end)

CreateThread(function()
    while true do
        local activity = Config.ActivityXP or {}
        if activity.Enabled ~= true then
            Wait(30000)
        else
            local interval = math.max(10, tonumber(activity.IntervalSeconds) or 60)
            Wait(interval * 1000)

            for _, playerId in ipairs(GetPlayers()) do
                local source = tonumber(playerId)
                if source then
                    local ped = GetPlayerPed(source)
                    if ped and ped > 0 and DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        local speed = GetEntitySpeed(ped)
                        local playerActivity = ActivityCache[source] or { idleIntervals = 0 }

                        local movedEnough = true
                        if activity.AFK and activity.AFK.Enabled and playerActivity.lastCoords then
                            local minDistance = tonumber(activity.AFK.MinDistance) or 1.5
                            local dx = coords.x - playerActivity.lastCoords.x
                            local dy = coords.y - playerActivity.lastCoords.y
                            local dz = coords.z - playerActivity.lastCoords.z
                            local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
                            movedEnough = distance >= minDistance
                        end

                        if movedEnough then
                            playerActivity.idleIntervals = 0
                        else
                            playerActivity.idleIntervals = (playerActivity.idleIntervals or 0) + 1
                        end

                        playerActivity.lastCoords = coords
                        ActivityCache[source] = playerActivity

                        local maxIdle = activity.AFK and tonumber(activity.AFK.MaxIdleIntervals) or 0
                        if playerActivity.idleIntervals > maxIdle then
                            goto continue
                        end

                        local xpToAdd = tonumber(activity.BasePlayXP) or 0

                        if activity.Driving and activity.Driving.Enabled then
                            local veh = GetVehiclePedIsIn(ped, false)
                            if veh and veh > 0 and GetPedInVehicleSeat(veh, -1) == ped then
                                local minSpeed = tonumber(activity.Driving.MinSpeed) or 12.0
                                if speed >= minSpeed then
                                    xpToAdd = xpToAdd + (tonumber(activity.Driving.BonusXP) or 0)
                                end
                            end
                        end

                        if activity.Running and activity.Running.Enabled and not IsPedInAnyVehicle(ped, false) then
                            local minRunSpeed = tonumber(activity.Running.MinSpeed) or 2.8
                            if speed >= minRunSpeed then
                                xpToAdd = xpToAdd + (tonumber(activity.Running.BonusXP) or 0)
                            end
                        end

                        if xpToAdd > 0 then
                            addXP(source, xpToAdd)
                        end
                    end
                end

                ::continue::
            end
        end
    end
end)
