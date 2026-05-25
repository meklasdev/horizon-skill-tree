local isMenuOpen = false
local isDataLoading = false

local function setMenuState(state)
    isMenuOpen = state
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
