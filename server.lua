local RSGCore = exports['rsg-core']:GetCoreObject()
local hiddenPlayers = {}

RegisterServerEvent('rsg-hiding:server:setHiddenState')
AddEventHandler('rsg-hiding:server:setHiddenState', function(state)
    local src = source
    if state then
        hiddenPlayers[src] = true
    else
        hiddenPlayers[src] = nil
    end
end)

RSGCore.Commands.Add('hiddenplayers', 'Show all hidden players (Admin Only)', {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.job.type == "leo" or IsPlayerAceAllowed(src, "command") then
        local hiddenCount = 0
        local playerList = ""
        
        -- Count hidden players and build name list
        for playerId, _ in pairs(hiddenPlayers) do
            local targetPlayer = RSGCore.Functions.GetPlayer(playerId)
            if targetPlayer then
                hiddenCount = hiddenCount + 1
                playerList = playerList .. targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname
                if hiddenCount > 1 then
                    playerList = playerList .. ", "  -- Add comma between names
                end
            end
        end
        
        -- Notify based on hidden players count
        if hiddenCount > 0 then
            TriggerClientEvent('rNotify:NotifyLeft', src, "HIDDEN PLAYERS: " .. hiddenCount, playerList, "generic_textures", "tick", 4000)
        else
            TriggerClientEvent('rNotify:NotifyLeft', src, "NO HIDDEN PLAYERS", "All players are visible", "generic_textures", "cross", 4000)
        end
    else
        TriggerClientEvent('rNotify:NotifyLeft', src, "PERMISSION DENIED", "You are not authorized to use this command", "generic_textures", "cross", 4000)
    end
end)