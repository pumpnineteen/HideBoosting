HBSavedFilteredMessages = HBSavedFilteredMessages or {}

local default_filteredChannels = {
    "lookingforgroup",
}

local default_filters = {
    "bo[o]+st",
    "xp%s+service",
    {
        pattern = "%f[%S]layer",
        exception = "[<]",
    },
    {
        pattern = "^layer",
        exception = "[<]",
    },
}

local filterPacks = {
    boost = {
        "bo[o]+st",
        "xp%s+service",
    },
    layer = {
        {
            pattern = "%f[%S]layer",
            exception = "[<]rend",
        },
        {
            pattern = "^layer",
            exception = "[<]rend",
        },
    },
}

local SPLIT_EXCEPTION = "%s*,%s*"
local SPLIT_PATTERN   = "%s*;%s*"

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

local function isTrue(v)
    if v then
        return true
    end
    return false
end

local function all(tbl, predicate)
    if predicate == nil then
        predicate = isTrue
    end
    for i, v in ipairs(tbl) do
        if not predicate(v) then
            return false
        end
    end
    return true
end

local function none(tbl, predicate)
    if predicate == nil then
        predicate = isTrue
    end
    for i, v in ipairs(tbl) do
        if predicate(v) then
            return false
        end
    end
    return true
end

local function any(tbl, predicate)
    if predicate == nil then
        predicate = isTrue
    end
    for i, v in ipairs(tbl) do
        if predicate(v) then
            return true
        end
    end
    return false
end

local function _findInTable(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return -1
end

local function _compareTables(tbl1, tbl2)
    if tbl1 == nil or tbl2 == nil then
        return {false}
    end
    if type(tbl1) ~= "table" or type(tbl2) ~= "table" then
        return {false}
    end
    
    local function _doCompare(tbl1, tbl2)
        local equals = {}
        for _, v in pairs(tbl1) do
            local found = _findInTable(tbl2, v) ~= -1
            table.insert(equals, found)
        end
        return equals
    end

    if #tbl1 >= #tbl2 then

        return _doCompare(tbl1, tbl2)
    else
        return _doCompare(tbl2, tbl1)
    end

end

local function findInTable(tbl, value)
    if type(value) == "table" then
        for i, v in ipairs(tbl) do
            if type(v) == "table" then
                if value.pattern then
                    if all(_compareTables(v.pattern, value.pattern)) and all(_compareTables(v.exception, value.exception)) then
                        return i
                    end
                else
                    if all(_compareTables(v, value)) then
                        return i
                    end
                end
            end
        end
    else 
        for i, v in ipairs(tbl) do
            if type(v) == "string" then
                if v == value then
                    return i
                end
            end
        end
    end
    return -1 
end

local function removeValueFromTable(tbl, value)
    local pos = findInTable(tbl, value)
    if pos ~= -1 then
        table.remove(tbl, pos)
    end
    return pos ~= -1
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

local function makePretty(tbl)
    if type(tbl) == "string" then
        return tbl
    end
    local pattern = "\n  Patterns:"
    if tbl.pattern then
        if type(tbl.pattern) == "string" then
            pattern = pattern .. "    " .. tbl.pattern .. "\n"
        else
            for _, p in ipairs(tbl.pattern) do
               pattern = pattern .. "    " ..  p .. "\n"  
            end
        end
        if tbl.exception then
            pattern = pattern .. "\n  Exceptions:"
            if type(tbl.exception) == "string" then
                pattern = pattern .. "    " .. tbl.exception .. "\n"
            else
                for _, e in ipairs(tbl.exception) do
                    pattern = pattern .. "    " ..  e .. "\n"  
                end
            end
        end
        return pattern
    end
    for _, p in ipairs(tbl) do
        pattern = pattern .. "    " ..  p .. "\n"  
    end
    return pattern
end

local function listFilters()
    for i, v in ipairs(filters) do
        if v.pattern then
            print(string.format("Except: ID:%d %s", i , makePretty(v)))
        else
            print(string.format("Filter: ID:%d %s", i, makePretty(v)))
        end
    end
end

local function listChannels()
    for _, v in ipairs(filteredChannels) do
        print("Channel:", v)
    end
end

local function listPacks()
    for k,_ in pairs(filterPacks) do
        print("Pack:", k)
    end
end

local function matchPattern(msg, pattern)
    return isTrue(msg:match(pattern))
end

local function matchPatterns(msg, pattern)
    if pattern == nil then
        return { false }
    end
    if type(pattern) == "string" then
        return { matchPattern(msg, pattern) } 
    elseif type(pattern) == "table" then
        local matches = {}
        for _, p in pairs(pattern) do
            table.insert(matches, matchPattern(msg, p))
        end
        return matches
    else 
        print("HB ERROR: unknown patten type", type(pattern))
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
                for _ , patternException in ipairs(filters) do
                    local pattern = patternException
                    local exception = nil
                    if patternException.pattern then
                        pattern = patternException.pattern
                        exception = patternException.exception
                    end
                    local p_matches = matchPatterns(lowerMsg, pattern)
                    local e_matches = matchPatterns(lowerMsg, exception)
                    if  all(p_matches) and none(e_matches) then
                        -- Log the filtered message with details.
                        local logEntry = {
                        time = date("%Y-%m-%d %H:%M:%S"),
                        sender = sender,
                        channel = channelName,
                        message = msg,
                        filter = patternException,
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
local function addHelp()
    local usage = [[
Add filter usage:
you can use a single pattern, or multiple patterns,
or single or multiple patterns with single or multiple exceptions

patterns and exceptions are separated with ,
multiple patterns and exceptions are separated with ;
example 1:
/hb add filter test1   -- adds a single pattern

example 2:
/hb add filter test1 ; test2  -- adds a multi patterns, where both test1 and test2 has to match
> ; < separates individual patterns test1 and test 2
     
example 3:
/hb add filter test1 , exception1 ; exception2 -- adds a single match pattern with multi exception patterns
all patterns must match, and none of the exceptions may match to filter
> , < separates pattern(s) and exception(s)

patterns must follow Lua pattern matching rules:
%s - white space
%a - alphabetical character
%d - digit character
.  - any character match
^  - constrains match to start at the beginning of the string (^ must be the first character of the pattern)
$  - constrains match to end at the end of the string ($ must be the last character of the pattern)
+  - a character followed by + means at least 1 of that character
*  - a character followed by * means zero or more of that character

]]

    print(usage)

end

local function printHelp(args)
    if args and #args >= 2 and args[1] == "help" and args[2] == "add" then
        addHelp()
    else
        local usage = [[
Usage:")
/hb clearlog -- clear the log
/hb log      -- toggle logging
/hb filter   -- toggle filtering
/hb add channel <channelName> -- add channelName to the filtered channels
/hb add filter pattern[ ; pattern2... , exception ; exception2...] -- add pattern[s] with optional exceptions to the filters
/hb add pack packname -- adds a predefined filter pack (see available packs with list pack)
/hb remove channel <channelName> -- remove channelName from the filtered channels
/hb remove filter "pattern" -- remove "pattern" from the filters
/hb remove pack packname -- remove predefined filter pack (see available packs with list pack)
/hb reset channel -- reset the filtered channels to the defaults
/hb reset filter  -- reset the filters to the defaults
/hb list channel  -- list the filtered
/hb list filter   -- list the filters
/hb list pack     -- list the available predefined filter packs
/hb help [add] -- print this help, or print add help
]]
        print(usage)

    end

end

local function buildFilterSimple(patterns)
    if matchPattern(patterns, SPLIT_PATTERN) then
        patterns = split(patterns, SPLIT_PATTERN)
    end
    return patterns
end

local function buildFilterException(thing)
    local patterns, exceptions = unpack(split(thing, SPLIT_EXCEPTION))
    if matchPattern(patterns, SPLIT_PATTERN) then
        patterns = split(patterns, SPLIT_PATTERN)
    end

    if matchPattern(exceptions, SPLIT_PATTERN) then
        exceptions = split(exceptions, SPLIT_PATTERN)
    end

    return {pattern = patterns, exception = exceptions}
end

local function buildFilter(thing)
    if matchPattern(thing, SPLIT_EXCEPTION) then
        return buildFilterException(thing)
    else 
        return buildFilterSimple(thing)
    end
end

local function handleAdd(args, msg)
    if #args < 3 then
        print("HB: Didn't recognise the arguments.", msg)
        return
    end
    if args[2] == "channel" then
        local thing = table.concat({ select(3, unpack(args)) }, " ")
        thing = thing:lower()
        local pos = findInTable(filteredChannels, thing)
        if pos == -1 then
            table.insert(filteredChannels, thing)
            print("HB: Added channel filter:", thing)
        else
            print("HB:", thing, "was already in channels")
        end
    elseif args[2] == "filter" then
        local thing = table.concat({ select(3, unpack(args)) }, " ")
        thing = makePatternLower(thing)
        local patterns = buildFilter(thing)
        removeValueFromTable(filters, patterns)
        table.insert(filters, patterns)
        print("HB: Added filter:", makePretty(patterns))
    elseif args[2] == "pack" then
        if filterPacks[args[3]] then
            for _, patterns in ipairs(filterPacks[args[3]]) do
                removeValueFromTable(filters, patterns)
                table.insert(filters, patterns)
                print("HB: Added filter:", makePretty(patterns))
            end
        else 
            print("HB: Couldn't find pack:", args[3])
        end
    else 
        print("HB: Didn't recognise the arguments.", msg)
    end
end

local function handleRemove(args, msg)
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
        local index = tonumber(args[3])
        if index then
            if index <= #filters then
                local filter = filters[index]
                table.remove(filters, index)
                print("HB: Removed filter:", makePretty(filter))
            else
                print("HB:", args[3], "was out of range!")
            end
            return
        end

        local thing = table.concat({ select(3, unpack(args)) }, " ")
        thing = makePatternLower(thing)
        thing = buildFilter(thing)
        if removeValueFromTable(filters, thing) then
            print("HB: Removed filter:", makePretty(thing))
        else
            print("HB:", thing, "wasn't in filters")
        end
    elseif args[2] == "pack" then
        if filterPacks[args[3]] then
            for _, patterns in ipairs(filterPacks[args[3]]) do
                removeValueFromTable(filters, patterns)
                print("HB: Removed filter:", makePretty(patterns))
            end
        else 
            print("HB: Couldn't find pack:", args[3])
        end
    else 
        print("HB: Didn't recognise the arguments.", msg)
    end
end

local function handleReset(args, msg)
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
end

local function handleList(args, msg)
    if #args ~= 2 then
        print("HB: Didn't recognise the arguments.", msg)
        return
    end
    if args[2] == "channel" then
        listChannels()
    elseif args[2] == "filter" then
        listFilters()
    elseif args[2] == "pack" then
        listPacks()
    else
        print("HB: Didn't recognise the arguments.", msg)
    end
end

local function HandleHBCommand(msg)
    msg = msg:trim()  -- Remove any leading/trailing whitespace.
    local args = split(msg)
    local _msg = args[1]

    if _msg == "" or _msg == "help" then
        printHelp(args)

    elseif _msg == "clearlog" then
        HBSavedFilteredMessages = {}  -- Clear the saved log.
        print("HB: Log has been cleared.")

    elseif _msg == "log" then
        toggleLog()

    elseif _msg == "filter" then
        toggleFiltering()
    elseif _msg == "add" then
        handleAdd(args, msg)
    elseif _msg == "except" then
        handleException(args, msg)
    elseif _msg == "remove" then
        handleRemove(args, msg)
    elseif _msg == "reset" then
        handleReset(args, msg)
    elseif _msg == "list" then
        handleList(args, msg)
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
