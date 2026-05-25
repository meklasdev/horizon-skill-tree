local ESX = exports['es_extended']:getSharedObject()
local PlayerDataCache = {}

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
    addXP(source, amount)
end)

RegisterNetEvent('horizon_skill_tree:server:addSkillPoints', function(amount)
    addSkillPoints(source, amount)
end)

RegisterNetEvent('horizon_skill_tree:server:removeSkillPoints', function(amount)
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

AddEventHandler('playerDropped', function()
    local source = source
    local data = PlayerDataCache[source]
    if not data then
        return
    end

    local identifier = getIdentifier(source)
    savePlayerData(identifier, data)
    PlayerDataCache[source] = nil
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
