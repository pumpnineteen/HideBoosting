HBSavedFilteredMessages = HBSavedFilteredMessages or {}

local filteredChannels = {
    "lookingforgroup",
}

local filters = {
    "boost",
    "xp\\s+service",
}
HBOptions = HBOptions or {}
local logging = HBOptions.logging or false
local stopFiltering = HBOptions.stopFiltering or false

HBOptions.logging = logging
HBOptions.stopFiltering = stopFiltering

local function toggleFiltering()
    stopFiltering = not stopFiltering
    if stopFiltering then
        print("Filtering disabled")
    else
        print("Filtering enabled")
    end
end

local function toggleLog()
    logging = not logging
    if logging then
        print("Logging enabled")
    else
        print("Logging disabled")
    end
end


local function FilterBoostMessages(self, event, msg, sender, languageName, channelName, target,
                                     flags, unknown, channelNumber, channelID, ...)
    if stopFiltering then
        return false
    end
    -- Convert to lowercase for case-insensitive matching.
    local lowerMsg = msg:lower()
    local lowerChannel = channelName:lower()

    --   print("checking:", lowerChannel, lowerMsg)

    -- Check if the message is from the "lookingforgroup" channel and contains "boost".
    for _, channel in ipairs(filteredChannels) do
            -- print("Checking channel:", lowerChannel, channel, lowerChannel == channel)
            if lowerChannel:find(channel) then
                -- print("Found channel:", channel)
                for _ , pattern in ipairs(filters) do
                    if lowerMsg:match(pattern) then
                        -- Log the filtered message with details.
                        local logEntry = {
                        time = date("%Y-%m-%d %H:%M:%S"),
                        sender = sender,
                        channel = channelName,
                        message = msg,
                        }
                        
                        -- Add the new entry to the saved variable table.
                        table.insert(HBSavedFilteredMessages, logEntry)
                        -- print("Filtering:", lowerChannel, lowerMsg)
                        return true  -- Filter (hide) the message from the chat display.
                    end
                end
            end
        end

    return false  -- Allow other messages to be displayed.
end

-- Register the filter for channel messages.
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", FilterBoostMessages)

-------------------------------------------------------------------
-- Slash Command Handling
-------------------------------------------------------------------

local function HandleHBCommand(msg, editBox)
    msg = msg:trim()  -- Remove any leading/trailing whitespace.
    if msg == "clearlog" then
        HBSavedFilteredMessages = {}  -- Clear the saved log.
        print("HideBoosting: Log has been cleared.")
    elseif msg == "log" then
        toggleLog()    
    elseif msg == "filter" then
        toggleFiltering()
    else
        print("HideBoosting: Unknown command. Use '/hb clearlog' to clear the log.")
    end
end

-- Register the slash command /hb.
SLASH_HB1 = "/hb"
SlashCmdList["HB"] = HandleHBCommand