Config = {} -- Don't touch this line

Config.ServerName = 'server name' -- Name of the server

Config.Debug = false -- Set to true to enable debug messages

Config.UseQbxLogs = true -- Set to true to send logs to qb-logs

Config.AdminGroup = 'admin' -- Permission group that can use whitelist commands

Config.Locales = {
    VPN_Detected = 'VPN Detected', -- Title of the card
    VPN_Detected_Message =
    'Joining with a VPN is not allowed. This can also be caused by things like cloud gaming!\nIf you are not using a VPN, you can create a ticket in our Discord.', -- Message of the card
    API_Error = '[🚧]: An error occurred in the API', -- Error message when the API fails
}

Config.Whitelist = {                        -- Add identifiers here to bypass VPN check
    -- 'char1:xxxxxxxx',                   -- Example format
    -- 'license:xxxxxxxx',  -- Replace with actual player license
    -- 'discord:123456789', -- Or discord ID

  
}

Config.DiscordURL = 'https://discord.gg/yourdiscord' -- Discord invite URL

Config.Buttons = {                          -- Here you can add buttons to the card (max 5 buttons)
    {
        title = 'Discord',                  -- Title of the button
        url = Config.DiscordURL, -- URL of the button
        style = 'positive',                 -- positive, destructive, default
    },
    -- Add more buttons here
}

-- More info about the buttons can be found here: https://adaptivecards.io/explorer/Action.OpenUrl.html
