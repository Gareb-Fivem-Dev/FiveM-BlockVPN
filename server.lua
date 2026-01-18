local adaptiveCard = {
    ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
    ["type"] = "AdaptiveCard",
    ["version"] = "1.6",
    ["body"] = {
        {
            ["type"] = "TextBlock",
            ["text"] = Config.ServerName .. ' - ' .. Config.Locales.VPN_Detected,
            ["weight"] = "bolder",
            ["size"] = "large",
            ["horizontalAlignment"] = "center",
            ["wrap"] = true,
        },
        {
            ["type"] = "TextBlock",
            ["text"] = Config.Locales.VPN_Detected_Message,
            ["size"] = "medium",
            ["horizontalAlignment"] = "center",
            ["wrap"] = true,
        },
        {
            ["type"] = "ActionSet",
            ["horizontalAlignment"] = "center",
            ["actions"] = {}
        },
    },
}

-- Function to send logs to qbx-logs
local function SendDenialLog(playerName, reason, identifiers, ip)
    if not Config.UseQbxLogs then return end
    
    -- Use table.concat for better performance than string concatenation
    local identifiersList = table.concat(identifiers, "\n")
    
    TriggerEvent('qb-log:server:CreateLog', 'vpn_blocker', 'Connection Denied', 'red', 
        string.format('**Player:** %s\n**Reason:** %s\n**IP:** %s\n**Identifiers:**\n%s', 
        playerName, reason, ip, identifiersList))
end

-- Function to save whitelist to config file
local function SaveWhitelistToFile()
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local configPath = resourcePath .. '/config.lua'
    
    -- Read current config file
    local file = io.open(configPath, 'r')
    if not file then
        print("^1[VPS_BLOCKER]^7 Error: Could not open config.lua for reading")
        return
    end
    
    local content = file:read('*all')
    file:close()
    
    -- Build new whitelist string using table for better performance
    local parts = {
        "Config.Whitelist = {                        -- Add identifiers here to bypass VPN check\n",
        "    -- 'char1:xxxxxxxx',                   -- Example format\n",
        "    -- 'license:xxxxxxxx',  -- Replace with actual player license\n",
        "    -- 'discord:123456789', -- Or discord ID\n"
    }
    
    for _, identifier in ipairs(Config.Whitelist) do
        parts[#parts + 1] = "    '" .. identifier .. "',\n"
    end
    
    parts[#parts + 1] = "}"
    local whitelistStr = table.concat(parts)
    
    -- Replace whitelist section in config
    local pattern = "Config%.Whitelist%s*=%s*{.-}"
    content = string.gsub(content, pattern, whitelistStr)
    
    -- Write back to file
    file = io.open(configPath, 'w')
    if not file then
        print("^1[VPS_BLOCKER]^7 Error: Could not open config.lua for writing")
        return
    end
    
    file:write(content)
    file:close()
    
    print("^2[VPS_BLOCKER]^7 Whitelist saved to config.lua")
end

Citizen.CreateThread(function()
    if Config.Buttons then
        for _, button in ipairs(Config.Buttons) do
            if button.title and button.url and button.style then
                table.insert(adaptiveCard.body[3].actions, {
                    ["type"] = "Action.OpenUrl",
                    ["title"] = button.title,
                    ["url"] = button.url,
                    ["style"] = button.style,
                })
            end
        end
    end
end)

-- Reload all player info on script restart
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    print("^3[VPS_BLOCKER]^7 Resource started - Checking all connected players...")
    
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        local playerIP = GetPlayerEndpoint(src)
        local identifiers = GetPlayerIdentifiers(src)
        
        if playerIP and identifiers then
            PerformHttpRequest("http://ip-api.com/json/" .. playerIP .. "?fields=66846719", function(err, text, headers)
                local data = json.decode(text)
                if data and data.status == "success" then
                    local isProxy = data.proxy or false
                    local identifiersString = json.encode(identifiers)
                    
                    -- Check if player already exists in database
                    local existingRecord = MySQL.single.await('SELECT id FROM vps_blocker_logs WHERE identifiers = ? LIMIT 1', {identifiersString})
                    
                    if existingRecord then
                        -- Update existing record
                        MySQL.update('UPDATE vps_blocker_logs SET ip = ?, is_proxy = ?, timestamp = NOW() WHERE id = ?', {
                            playerIP,
                            isProxy,
                            existingRecord.id
                        })
                        if Config.Debug then
                            print("^5[VPS_BLOCKER]^7 Updated player " .. playerId .. " in database - Proxy: " .. tostring(isProxy))
                        end
                    else
                        -- Insert new record
                        MySQL.insert('INSERT INTO vps_blocker_logs (identifiers, ip, is_proxy, timestamp) VALUES (?, ?, ?, NOW())', {
                            identifiersString,
                            playerIP,
                            isProxy
                        })
                        if Config.Debug then
                            print("^5[VPS_BLOCKER]^7 Logged player " .. playerId .. " to database - Proxy: " .. tostring(isProxy))
                        end
                    end
                end
            end)
        end
    end
    
    print("^2[VPS_BLOCKER]^7 Finished reloading player information")
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    local playerIP = GetPlayerEndpoint(src)

    deferrals.defer()
    
    -- Add delay to let FiveM process identifiers
    Wait(100)

    if not playerIP then
        deferrals.done(Config.Locales.API_Error)
        return
    end

    -- Check if player is whitelisted first and check fivem ID in same loop for efficiency
    local isWhitelisted = false
    local identifiers = GetPlayerIdentifiers(src)
    local hasFiveMID = false
    
    -- Create whitelist lookup table for O(1) instead of O(n) lookup
    local whitelistLookup = {}
    for _, id in ipairs(Config.Whitelist) do
        whitelistLookup[id] = true
    end
    
    if Config.Debug then
        print("^2[VPS_BLOCKER]^7 Checking player identifiers...")
    end
    
    -- Single loop to check both whitelist and fivem ID
    for _, identifier in ipairs(identifiers) do
        if Config.Debug then
            print("^2[VPS_BLOCKER]^7 Identifier: " .. identifier)
        end
        
        -- Check whitelist
        if whitelistLookup[identifier] then
            isWhitelisted = true
            if Config.Debug then
                print("^3[VPS_BLOCKER]^7 Player is whitelisted: " .. identifier)
            end
        end
        
        -- Check fivem ID
        if string.match(identifier, "^fivem:") then
            hasFiveMID = true
        end
        
        -- Early exit if both found
        if isWhitelisted and hasFiveMID then
            break
        end
    end

    -- If whitelisted, skip all checks
    if isWhitelisted then
        if Config.Debug then
            print("^2[VPS_BLOCKER]^7 Whitelisted player - Bypassing all checks!")
        end
        deferrals.done()
        return
    end

    -- If player doesn't have a fivem identifier, block them
    if not hasFiveMID then
        if Config.Debug then
            print("^1[VPS_BLOCKER]^7 Player rejected: No FiveM identifier found!")
        end
        
        -- Send log to qbx-logs
        Citizen.SetTimeout(100, function()
            SendDenialLog(name, "No FiveM Identifier", identifiers, playerIP)
        end)
        
        deferrals.done("You do not have permission to join this server. A FiveM identifier is required. Login to FiveM/CFX and try again.\n\nNeed help? Join our Discord: " .. (Config.DiscordURL))
        return
    end
    
    if Config.Debug then
        print("^2[VPS_BLOCKER]^7 Player passed FiveM check!")
    end
    
    if Config.Debug then
        print("^3[VPS_BLOCKER]^7 Player IP: " .. playerIP .. " - Checking VPN...")
    end

    -- Check database first to see if IP was previously checked and clean
    local identifiersString = json.encode(identifiers)
    local cachedRecord = MySQL.single.await('SELECT is_proxy FROM vps_blocker_logs WHERE ip = ? AND is_proxy = 0 LIMIT 1', {playerIP})
    
    if cachedRecord then
        if Config.Debug then
            print("^2[VPS_BLOCKER]^7 IP found in database with clean record - Bypassing API check")
        end
        
        -- Update asynchronously to not block connection
        MySQL.Async.execute('UPDATE vps_blocker_logs SET identifiers = ?, timestamp = NOW() WHERE ip = ?', {
            identifiersString,
            playerIP
        })
        
        deferrals.done()
        return
    end

    PerformHttpRequest("http://ip-api.com/json/" .. playerIP .. "?fields=66846719", function(err, text, headers)
        local data = json.decode(text)
        if data and data.status == "success" then
            local isProxy = data.proxy or false
            
            -- Store/Update player connection data in database
            local identifiersString = json.encode(identifiers)
            
            -- Check if player already exists in database (by any identifier)
            local existingRecord = MySQL.single.await('SELECT id FROM vps_blocker_logs WHERE identifiers = ? LIMIT 1', {identifiersString})
            
            if existingRecord then
                -- Update existing record
                MySQL.update('UPDATE vps_blocker_logs SET ip = ?, is_proxy = ?, timestamp = NOW() WHERE id = ?', {
                    playerIP,
                    isProxy,
                    existingRecord.id
                })
                if Config.Debug then
                    print("^5[VPS_BLOCKER]^7 Updated existing record in database - Proxy: " .. tostring(isProxy))
                end
            else
                -- Insert new record
                MySQL.insert('INSERT INTO vps_blocker_logs (identifiers, ip, is_proxy, timestamp) VALUES (?, ?, ?, NOW())', {
                    identifiersString,
                    playerIP,
                    isProxy
                })
                if Config.Debug then
                    print("^5[VPS_BLOCKER]^7 Logged new connection to database - Proxy: " .. tostring(isProxy))
                end
            end
            
            if data.proxy then
                if Config.Debug then
                    print("^1[VPS_BLOCKER]^7 VPN DETECTED! Blocking player...")
                end
                
                -- Send log to qbx-logs asynchronously
                Citizen.SetTimeout(100, function()
                    SendDenialLog(name, "VPN/Proxy Detected", identifiers, playerIP)
                end)
                
                -- Use done() with message instead of presentCard for better compatibility
                deferrals.done(string.format("%s - %s\n\n%s\n\nJoin our Discord: %s", 
                    Config.ServerName, 
                    Config.Locales.VPN_Detected, 
                    Config.Locales.VPN_Detected_Message,
                    Config.DiscordURL ))
                return
            else
                if Config.Debug then
                    print("^2[VPS_BLOCKER]^7 No VPN detected - Player allowed!")
                end
                deferrals.done()
                return
            end
        else
            if Config.Debug then
                print("^1[VPS_BLOCKER]^7 API Error occurred")
            end
            deferrals.done(Config.Locales.API_Error)
            return
        end
    end)
end)

-- Command to add player to whitelist
RegisterCommand('vpnwhitelist', function(source, args, rawCommand)
    -- Check if player has permission (admin check)
    if source > 0 then
        local hasPermission = false
        
        -- Check if player is in admin group
        local identifiers = GetPlayerIdentifiers(source)
        for _, identifier in ipairs(identifiers) do
            if IsPlayerAceAllowed(source, 'admin') or IsPrincipalAceAllowed(identifier, 'admin') then
                hasPermission = true
                break
            end
        end
        
        if not hasPermission then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"VPN Blocker", "You don't have permission to use this command!"}
            })
            return
        end
    end
    
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 0},
            multiline = true,
            args = {"VPN Blocker", "Usage: /vpnwhitelist <add/remove/list> [player id or identifier]"}
        })
        return
    end
    
    local action = string.lower(args[1])
    
    if action == "list" then
        -- List all whitelisted identifiers
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"VPN Blocker", "Current whitelist:"}
        })
        for i, identifier in ipairs(Config.Whitelist) do
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                args = {"", i .. ". " .. identifier}
            })
        end
        
    elseif action == "add" then
        if #args < 2 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                args = {"VPN Blocker", "Usage: /vpnwhitelist add <player id or identifier>"}
            })
            return
        end
        
        local target = args[2]
        local identifier = nil
        
        -- Check if it's a player ID
        if tonumber(target) then
            local playerId = tonumber(target)
            local identifiers = GetPlayerIdentifiers(playerId)
            if identifiers and #identifiers > 0 then
                -- Get license2 identifier
                for _, id in ipairs(identifiers) do
                    if string.match(id, "^license2:") then
                        identifier = id
                        break
                    end
                end
                if not identifier then
                    identifier = identifiers[1] -- Use first identifier if no license2
                end
            else
                TriggerClientEvent('chat:addMessage', source, {
                    color = {255, 0, 0},
                    args = {"VPN Blocker", "Player not found!"}
                })
                return
            end
        else
            -- It's an identifier
            identifier = target
        end
        
        -- Check if already whitelisted
        for _, id in ipairs(Config.Whitelist) do
            if id == identifier then
                TriggerClientEvent('chat:addMessage', source, {
                    color = {255, 255, 0},
                    args = {"VPN Blocker", "Identifier already whitelisted!"}
                })
                return
            end
        end
        
        -- Add to whitelist
        table.insert(Config.Whitelist, identifier)
        
        -- Save to config file
        SaveWhitelistToFile()
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"VPN Blocker", "Added to whitelist: " .. identifier}
        })
        
        print("^2[VPS_BLOCKER]^7 Added to whitelist: " .. identifier)
        
    elseif action == "remove" then
        if #args < 2 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                args = {"VPN Blocker", "Usage: /vpnwhitelist remove <identifier or list number>"}
            })
            return
        end
        
        local target = args[2]
        local removed = false
        
        -- Check if it's a number (list index)
        if tonumber(target) then
            local index = tonumber(target)
            if Config.Whitelist[index] then
                local identifier = Config.Whitelist[index]
                table.remove(Config.Whitelist, index)
                TriggerClientEvent('chat:addMessage', source, {
                    color = {0, 255, 0},
                    args = {"VPN Blocker", "Removed from whitelist: " .. identifier}
                })
                print("^2[VPS_BLOCKER]^7 Removed from whitelist: " .. identifier)
                removed = true
            end
        else
            -- Remove by identifier
            for i, id in ipairs(Config.Whitelist) do
                if id == target then
                    table.remove(Config.Whitelist, i)
                    TriggerClientEvent('chat:addMessage', source, {
                        color = {0, 255, 0},
                        args = {"VPN Blocker", "Removed from whitelist: " .. target}
                    })
                    print("^2[VPS_BLOCKER]^7 Removed from whitelist: " .. target)
                    removed = true
                    break
                end
            end
        end
        
        if not removed then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                args = {"VPN Blocker", "Identifier not found in whitelist!"}
            })
        else
            -- Save to config file
            SaveWhitelistToFile()
        end
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 0},
            multiline = true,
            args = {"VPN Blocker", "Usage: /vpnwhitelist <add/remove/list> [player id or identifier]"}
        })
    end
end, false)

-- Command to restart the resource
RegisterCommand('vpnrestart', function(source, args, rawCommand)
    -- Check if player has permission (admin check)
    if source > 0 then
        local hasPermission = false
        
        -- Check if player is in admin group
        local identifiers = GetPlayerIdentifiers(source)
        for _, identifier in ipairs(identifiers) do
            if IsPlayerAceAllowed(source, 'admin') or IsPrincipalAceAllowed(identifier, 'admin') then
                hasPermission = true
                break
            end
        end
        
        if not hasPermission then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"VPN Blocker", "You don't have permission to use this command!"}
            })
            return
        end
    end
    
    local resourceName = GetCurrentResourceName()
    
    if source > 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {"VPN Blocker", "Reloading configuration..."}
        })
    end
    
    print("^3[VPS_BLOCKER]^7 Reloading resource configuration via command...")
    
    -- Stop and start the resource
    SetTimeout(500, function()
        StopResource(resourceName)
        SetTimeout(1000, function()
            StartResource(resourceName)
        end)
    end)
end, false)
