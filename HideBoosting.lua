HBSavedFilteredMessages = HBSavedFilteredMessages or {}

local default_filteredChannels = {
    "lookingforgroup",
}

local default_filters = {
    "bo[o]+st",
    "xp\\s+service",
}

local logging
local stopFiltering
local filteredChannels
local filters

local function split(inputstr, delimiter)
    if delimiter == nil then
        delimiter = "%s"  -- Default: split by whitespace.
    end
    local result = {}
    for substr in string.gmatch(inputstr, "([^" .. delimiter .. "]+)") do
        table.insert(result, substr)
    end
    return result
end

local function join(things, joiner)
    if type(joiner) ~= "string" then
        error("Joiner must be a string!", joiner)
        return nil
    end
    local result = ""
    for i, v in ipairs(things) do
        result = result .. tostring(v)
        if i < #things then
            result = result .. joiner
        end
    end
    return result
end

local function removeValueFromTable(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

local function makePatternLower(pat)
    local result = ""
    local i = 1
    while i <= #pat do
        local c = pat:sub(i, i)
        if c == "%" and i < #pat then
            result = result .. pat:sub(i, i + 1)
            i = i + 2
        elseif c == "\\" and i < #pat then
            local c2 = pat:sub(i + 1, i + 1)
            if c2 == "\\" and i + 2 <= #pat then
                result = result .. pat:sub(i, i + 2)
                i = i + 3
            else
                result = result .. pat:sub(i, i)
                i = i + 1
            end    
        elseif c:match("%a") then
            result = result .. c:lower()
            i = i + 1
        else
            result = result .. c
            i = i + 1
        end
    end
    return result
end

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
local function printHelp()
    print("Usage:")
    print("/hb clearlog -- clear the log")
    print("/hb log      -- toggle logging")
    print("/hb filter   -- toggle filtering")
    print("/hb add channel <channelName> -- add channelName to the filtered channels")
    print('/hb add filter "pattern" -- add "pattern" to the filters')
    print("/hb remove channel <channelName> -- remove channelName from the filtered channels")
    print('/hb remove filter "pattern" -- remove "pattern" from the filters')
    print("/hb reset channel -- reset the filtered channels to the defaults")
    print('/hb reset filter  -- reset the filters to the defaults')

end
local function HandleHBCommand(msg)
    msg = msg:trim()  -- Remove any leading/trailing whitespace.
    local args = split(msg)
    local _msg = args[1]

    if _msg == "" or _msg == "help" then
        printHelp()

    elseif _msg == "clearlog" then
        HBSavedFilteredMessages = {}  -- Clear the saved log.
        print("HB: Log has been cleared.")

    elseif _msg == "log" then
        toggleLog()

    elseif _msg == "filter" then
        toggleFiltering()

    elseif _msg == "add" then
        if #args < 3 then
            print("HB: Didn't recognise the arguments.", msg)
            return
        end
        if args[2] == "channel" then
            local thing = table.concat({ select(3, unpack(args)) }, " ")
            thing = thing:lower()
            table.insert(filteredChannels, thing)
            print("HB: Added channel filter:", thing)
        elseif args[2] == "filter" then
            local thing = table.concat({ select(3, unpack(args)) }, " ")
            thing = makePatternLower(thing)
            table.insert(filters, thing)
            print("HB: Added filter:", thing)
        else 
            print("HB: Didn't recognise the arguments.", msg)
        end

    elseif _msg == "remove" then
        if #args < 3 then
            print("HB: Didn't recognise the arguments.", msg)
            return
        end
        if args[2] == "channel" then
            local thing = table.concat({ select(3, unpack(args)) }, " ")
            thing = thing:lower()
            if removeValueFromTable(filteredChannels, thing) then
                print("HB: Removed channel filter:", thing)
            else
                print("HB:", thing, "wasn't in channels")
            end
        elseif args[2] == "filter" then
            local thing = table.concat({ select(3, unpack(args)) }, " ")
            thing = makePatternLower(thing)
            if removeValueFromTable(filters, thing) then
                print("HB: Removed filter:", thing)
            else
                print("HB:", thing, "wasn't in filters")
            end
        else 
            print("HB: Didn't recognise the arguments.", msg)
        end

    elseif _msg == "reset" then
        if #args ~= 2 then
            print("HB: Didn't recognise the arguments.", msg)
            return
        end
        if args[2] == "channel" then
            filteredChannels = default_filteredChannels
            print("HB: Reset channel filters to default.")
        elseif args[2] == "filter" then
            filters = default_filters
            print("HB: Reset filters to default.")
        else
            print("HB: Didn't recognise the arguments.", msg)
        end

    else
        print("HideBoosting: Unknown command.", msg)
        printHelp()
    end
end

-- Register the slash command /hb.
SLASH_HB1 = "/hb"
SlashCmdList["HB"] = HandleHBCommand

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    HBOptions = HBOptions or {}
    logging = HBOptions.logging or false
    stopFiltering = HBOptions.stopFiltering or false
    filteredChannels = HBOptions.filteredChannels or default_filteredChannels
    filters = HBOptions.filters or default_filters
    
    HBOptions.logging = logging
    HBOptions.stopFiltering = stopFiltering
    HBOptions.filteredChannels = filteredChannels
    HBOptions.filters = filters
end)
