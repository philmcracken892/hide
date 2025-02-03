-- client.lua
local RSGCore = exports['rsg-core']:GetCoreObject()
local isHiding = false
local currentObject = nil
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local startPosition = nil
local isPlayingAnimation = false

local function InitializeTargets()
    -- Convert hash keys to their string representation for proper targeting
    for hash, config in pairs(Config.HideableObjects) do
        local modelHash = hash
        if type(hash) == 'number' then
            modelHash = tostring(hash)
        end
        
        exports['rsg-target']:AddTargetModel(modelHash, {
            options = {
                {
                    type = "client",
                    event = "rsg-hiding:client:toggleHide",
                    icon = "fas fa-eye-slash",
                    label = "Hide Here",
                    canInteract = function(entity)
                        if isHiding then 
                            return currentObject == entity
                        end
                        return not IsObjectOccupied(entity)
                    end
                },
            },
            distance = 2.0,
        })
    end
end

RegisterNetEvent('rsg-hiding:client:toggleHide')
AddEventHandler('rsg-hiding:client:toggleHide', function(data)
    local entity = data.entity
    
    if isHiding then
        ExitHiding()
    else
        HideInObject(entity)
    end
end)

-- Initialize targets when resource starts
CreateThread(function()
    InitializeTargets()
end)


function PlayHideAnimation(dict, anim, flag)
    local ped = PlayerPedId()
    isPlayingAnimation = true
    
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(100)
    end
    
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag, 0, true, 0, false, 0, false)
    
    Citizen.CreateThread(function()
        while isPlayingAnimation do
            if not IsEntityPlayingAnim(ped, dict, anim, 3) then
                isPlayingAnimation = false
            end
            Wait(100)
        end
        RemoveAnimDict(dict)
    end)
    
    if dict == "script_rc@cldn@ig@rsc2_ig1_questionshopkeeper" then
        return 4000
    elseif dict == "script_re@gold_panner@gold_success" then
        return 1000
    end
    return 1000
end

function CanPlayerHide()
    local ped = PlayerPedId()
    return not IsPedDeadOrDying(ped, true) 
        and not IsPedInCombat(ped, 0) 
        and not IsPedSwimming(ped)
        and not IsPedClimbing(ped)
end

-- Function to make player completely hidden
function SetPlayerFullyHidden()
    local ped = PlayerPedId()
    
    SetPedCanRagdoll(ped, false)
    SetEntityVisible(ped, false)
    SetEntityAlpha(ped, 0, false)
    
    SetEntityCollision(ped, false, false)
    NetworkSetEntityInvisibleToNetwork(ped, true)
    
    Citizen.InvokeNative(0x7CA657A4216D5FCD, true)
    
    Citizen.InvokeNative(0x241E289B5C059EDC, ped, true)
    SetEveryoneIgnorePlayer(PlayerPedId(), true)
end

function SetPlayerUnhidden()
    local ped = PlayerPedId()
    
    SetPedCanRagdoll(ped, true)
    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255, false)
    
    SetEntityCollision(ped, true, true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    
    Citizen.InvokeNative(0x7CA657A4216D5FCD, false)
    
    Citizen.InvokeNative(0x241E289B5C059EDC, ped, false)
    SetEveryoneIgnorePlayer(PlayerPedId(), false)
end

function IsObjectOccupied(object)
    local objectCoords = GetEntityCoords(object)
    local players = GetActivePlayers()
    
    for _, playerId in ipairs(players) do
        local playerPed = GetPlayerPed(playerId)
        if playerPed ~= PlayerPedId() then  -- Don't check self
            local playerCoords = GetEntityCoords(playerPed)
            if #(objectCoords - playerCoords) < 1.0 then
                return true
            end
        end
    end
    return false
end

-- Function to hide in object
function HideInObject(object)
    if not CanPlayerHide() or isPlayingAnimation then
		TriggerEvent('rNotify:NotifyLeft', "You cannot hide right now", "DAMN", "generic_textures", "tick", 4000)
        return
    end

    local ped = PlayerPedId()
    local model = GetEntityModel(object)
    local objectConfig = Config.HideableObjects[model]
    
    if not objectConfig then return end
    
    startPosition = GetEntityCoords(ped)
    
    local animDuration = PlayHideAnimation("script_rc@cldn@ig@rsc2_ig1_questionshopkeeper", "inspectfloor_player", 1)
    Wait(animDuration * 0.5)
    
    isHiding = true
    currentObject = object

    SetPlayerFullyHidden()

    local objectCoords = GetEntityCoords(object)
    SetEntityCoords(ped, objectCoords.x, objectCoords.y, objectCoords.z, false, false, false, false)

    AttachEntityToEntity(ped, object, 0, 
        objectConfig.offset.x, 
        objectConfig.offset.y, 
        objectConfig.offset.z,
        0.0, 0.0, objectConfig.rotation,
        false, false, false, false, 0, true)
		TriggerEvent('rNotify:NotifyLeft', "hiding", "cowboy", "generic_textures", "tick", 4000)

    Citizen.Wait(100)
    if not IsEntityAttached(ped) then
        SetEntityCoords(ped, startPosition.x, startPosition.y, startPosition.z, false, false, false, false)
        SetPlayerUnhidden()
		TriggerEvent('rNotify:NotifyLeft', "Failed to hide properly", "DAMN", "generic_textures", "tick", 4000)
        return
    end

    Wait(animDuration * 0.5)

    TriggerServerEvent('rsg-hiding:server:setHiddenState', true)
    RSGCore.Functions.Notify('You are now hiding', 'success')

    Citizen.CreateThread(function()
        while isHiding do
            local nearbyPeds = GetGamePool('CPed')
            for _, npc in pairs(nearbyPeds) do
                if not IsPedAPlayer(npc) and IsPedInCombat(npc, ped) then
					TriggerEvent('rNotify:NotifyLeft', "You have been discovered!", "DAMN", "generic_textures", "tick", 4000)
                    ExitHiding()
                    break
                end
            end
            Wait(1000)
        end
    end)
end

function ExitHiding()
    if not isHiding or not startPosition or isPlayingAnimation then return end

    local ped = PlayerPedId()
    
    local animDuration = PlayHideAnimation("script_re@gold_panner@gold_success", "SEARCH02", 1)
    Wait(animDuration * 0.5)
    
    DetachEntity(ped, true, false)
    
    Citizen.Wait(0)
    
    SetEntityCoords(ped, startPosition.x, startPosition.y, startPosition.z, false, false, false, false)
    
    SetPlayerUnhidden()
    
    Wait(animDuration * 0.5)
    
    isHiding = false
    currentObject = nil
    startPosition = nil
    
    TriggerServerEvent('rsg-hiding:server:setHiddenState', false)
	TriggerEvent('rNotify:NotifyLeft', "You have emerged from hiding!", "BOO", "generic_textures", "tick", 4000)
end




local function GetNearestHideableObject()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local nearbyObjects = GetGamePool('CObject')
    local nearestObject = nil
    local shortestDistance = 2.0
    
    for _, object in pairs(nearbyObjects) do
        local model = GetEntityModel(object)
        local modelHash = model
        if type(model) == 'number' then
            modelHash = tostring(model)
        end
        
        if Config.HideableObjects[modelHash] then
            local objectCoords = GetEntityCoords(object)
            local distance = #(coords - objectCoords)
            
            if distance < shortestDistance then
                nearestObject = object
                shortestDistance = distance
            end
        end
    end
    
    return nearestObject
end

Citizen.CreateThread(function()
    -- Create Hide/Exit prompt
    local hidePrompt = PromptRegisterBegin()
    PromptSetControlAction(hidePrompt, 0x760A9C6F) -- [G] key
    PromptSetText(hidePrompt, CreateVarString(10, 'LITERAL_STRING', 'Hide'))
    PromptSetEnabled(hidePrompt, true)
    PromptSetVisible(hidePrompt, true)
    PromptSetHoldMode(hidePrompt, true)
    PromptSetGroup(hidePrompt, promptGroup)
    PromptRegisterEnd(hidePrompt)

    while true do
        local wait = 1000
        local ped = PlayerPedId()
        
        if not isHiding then
            local nearestObject = GetNearestHideableObject()
            
            if nearestObject then
                wait = 0
                local promptName = CreateVarString(10, 'LITERAL_STRING', 'Hide')
                PromptSetActiveGroupThisFrame(promptGroup, promptName)

                if PromptHasHoldModeCompleted(hidePrompt) then
                    if IsObjectOccupied(nearestObject) then
						TriggerEvent('rNotify:NotifyLeft', "This hiding spot is occupied!", "SHIT", "generic_textures", "tick", 4000)
						
                    else
                        HideInObject(nearestObject)
                    end
                end
            end
        else
            wait = 0
            local promptName = CreateVarString(10, 'LITERAL_STRING', 'Exit Hiding')
            PromptSetActiveGroupThisFrame(promptGroup, promptName)

            if PromptHasHoldModeCompleted(hidePrompt) then
                ExitHiding()
            end
        end

        Wait(wait)
    end
end)

CreateThread(function()
    InitializeTargets()
end)

-- Event handlers
RegisterNetEvent('rsg-hiding:client:forceUnhide')
AddEventHandler('rsg-hiding:client:forceUnhide', function()
    if isHiding then
        ExitHiding()
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        if victim == PlayerPedId() and isHiding then
            ExitHiding()
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isHiding then
        SetPlayerUnhidden()
        ExitHiding()
    end
end)