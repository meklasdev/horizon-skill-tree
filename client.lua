local isMenuOpen = false
local isDataLoading = false
local menuCam = nil
local menuIntroCam = nil

local HAND_BONES = {
    left = 18905,
    right = 57005
}

local function destroyMenuCams()
    if menuCam and DoesCamExist(menuCam) then
        DestroyCam(menuCam, false)
    end

    if menuIntroCam and DoesCamExist(menuIntroCam) then
        DestroyCam(menuIntroCam, false)
    end

    menuCam = nil
    menuIntroCam = nil
end

local function stopMenuCamera()
    RenderScriptCams(false, true, 500, true, true)
    destroyMenuCams()
end

local function startMenuCamera()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    destroyMenuCams()

    local gameplayCamCoords = GetGameplayCamCoord()
    local gameplayCamRot = GetGameplayCamRot(2)

    menuIntroCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(menuIntroCam, gameplayCamCoords.x, gameplayCamCoords.y, gameplayCamCoords.z)
    SetCamRot(menuIntroCam, gameplayCamRot.x, gameplayCamRot.y, gameplayCamRot.z, 2)
    SetCamFov(menuIntroCam, GetGameplayCamFov())
    SetCamActive(menuIntroCam, true)
    RenderScriptCams(true, true, 0, true, true)

    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.75)
    local lookAtCoords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)

    menuCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(menuCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(menuCam, lookAtCoords.x, lookAtCoords.y, lookAtCoords.z + 0.02)
    SetCamFov(menuCam, 45.0)
    SetCamActive(menuCam, true)
    SetCamActiveWithInterp(menuCam, menuIntroCam, 900, true, true)

    CreateThread(function()
        Wait(1100)
        if menuIntroCam and DoesCamExist(menuIntroCam) then
            DestroyCam(menuIntroCam, false)
            menuIntroCam = nil
        end
    end)
end

local function sendHandAnchors()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    local leftCoords = GetPedBoneCoords(ped, HAND_BONES.left, 0.0, 0.0, 0.0)
    local rightCoords = GetPedBoneCoords(ped, HAND_BONES.right, 0.0, 0.0, 0.0)

    local leftVisible, leftX, leftY = GetScreenCoordFromWorldCoord(leftCoords.x, leftCoords.y, leftCoords.z)
    local rightVisible, rightX, rightY = GetScreenCoordFromWorldCoord(rightCoords.x, rightCoords.y, rightCoords.z)

    SendNUIMessage({
        action = 'setAnchors',
        anchors = {
            left = {
                x = leftX,
                y = leftY,
                visible = leftVisible
            },
            right = {
                x = rightX,
                y = rightY,
                visible = rightVisible
            }
        }
    })
end

local function getSyncCombatEventName()
    return (Config.Triggers and Config.Triggers.SyncCombatServer) or 'horizon_skill_tree:server:syncCombat'
end

local function setMenuState(state)
    isMenuOpen = state
    if state then
        startMenuCamera()
        sendHandAnchors()
    else
        stopMenuCamera()
    end

    SetNuiFocus(state, state)
    SendNUIMessage({
        action = state and 'open' or 'close'
    })
end

local function closeMenu()
    if not isMenuOpen then
        return
    end

    setMenuState(false)
end

local function requestAndOpenMenu()
    if isDataLoading then
        return
    end

    isDataLoading = true
    TriggerServerEvent('horizon_skill_tree:server:requestData')
end

local function toggleMenu()
    if isMenuOpen then
        closeMenu()
        return
    end

    requestAndOpenMenu()
end

RegisterCommand(Config.OpenCommand, function()
    toggleMenu()
end, false)

RegisterKeyMapping(Config.OpenCommand, Config.OpenDescription, 'keyboard', Config.DefaultKey)

RegisterNetEvent((Config.Triggers and Config.Triggers.OpenMenuClient) or 'horizon_skill_tree:client:toggleMenu', function()
    toggleMenu()
end)

RegisterNetEvent('horizon_skill_tree:client:open', function(payload)
    isDataLoading = false

    if not payload or not payload.player or not payload.skills then
        return
    end

    SendNUIMessage({
        action = 'setData',
        player = payload.player,
        skills = payload.skills
    })

    if Config.Combat and Config.Combat.Enabled then
        TriggerServerEvent(getSyncCombatEventName())
    end

    if not isMenuOpen then
        setMenuState(true)
    end
end)

RegisterNetEvent('horizon_skill_tree:client:updateData', function(playerData)
    SendNUIMessage({
        action = 'setPlayerData',
        player = playerData
    })
end)

RegisterNetEvent('horizon_skill_tree:client:purchaseResult', function(success, message)
    if message and message ~= '' then
        TriggerEvent('esx:showNotification', message)
    end

    SendNUIMessage({
        action = 'purchaseResult',
        success = success,
        message = message
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('purchaseSkill', function(data, cb)
    if not data or not data.skillId then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('horizon_skill_tree:server:purchaseSkill', data.skillId)
    cb({ ok = true })
end)

RegisterNetEvent('horizon_skill_tree:client:applyCombat', function(mods)
    if not Config.Combat or not Config.Combat.Enabled then
        SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
        SetPlayerMeleeWeaponDamageModifier(PlayerId(), 1.0)
        return
    end

    local weaponBonus = (mods and tonumber(mods.weapon)) or 0.0
    local meleeBonus = (mods and tonumber(mods.melee)) or 0.0

    local weaponModifier = 1.0 + math.max(0.0, weaponBonus)
    local meleeModifier = 1.0 + math.max(0.0, meleeBonus)

    SetPlayerWeaponDamageModifier(PlayerId(), weaponModifier)
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), meleeModifier)
end)

RegisterNetEvent('horizon_skill_tree:client:requestCombatSync', function()
    if Config.Combat and Config.Combat.Enabled then
        TriggerServerEvent(getSyncCombatEventName())
    end
end)

AddEventHandler('playerSpawned', function()
    if Config.Combat and Config.Combat.Enabled and Config.Combat.ReapplyOnSpawn then
        TriggerServerEvent(getSyncCombatEventName())
    end
end)

CreateThread(function()
    while true do
        if isMenuOpen then
            sendHandAnchors()
            Wait(120)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if isMenuOpen then
            -- Blokada poruszania i ataków podczas otwartego NUI.
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)

            DisablePlayerFiring(PlayerPedId(), true)

            Wait(0)
        else
            Wait(300)
        end
    end
end)
