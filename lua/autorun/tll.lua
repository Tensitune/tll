--[[-------------------------------------------------------------------------
Tensitune's Lightweight Library for Garry's Mod
Copyright (c) 2022 Tensitune

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-----------------------------------------------------------------------------]]
local version = 20230611
if tll and tll.version > version then return end

tll = tll or {}
tll.version = version

tll.types = {
    ["string"] = "string",
    ["number"] = "number",
    ["bool"] = "boolean",
    ["boolean"] = "boolean",
    ["table"] = "table",
    ["function"] = "function",
}

tll.colors = {
    primary = Color(253, 77, 89),
    warning = Color(250, 180, 50),
    white = Color(255, 255, 255),
    path = Color(210, 210, 210),
}

local function initFile(directoryPath, fileName)
    local prefix = string.Explode("_", string.lower(fileName))[1]
    local pathToFile = directoryPath .. "/" .. fileName

    if (prefix == "sv" or prefix == "server") and SERVER then
        tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
        include(pathToFile)
    elseif prefix == "cl" or prefix == "client" then
        if SERVER then AddCSLuaFile(pathToFile) end
        if CLIENT then include(pathToFile) end
    else
        if SERVER then
            AddCSLuaFile(pathToFile)
            tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
        end

        include(pathToFile)
    end
end

--- Just a logger.
--- Accepts many arguments.
--- @param prefix string @Console message prefix
function tll.Log(prefix, ...)
    local args = {...}
    if #args == 0 then return end

    local lastArg = args[#args]

    if lastArg and type(lastArg) == "string" and string.Right(lastArg, 2) ~= "\n" then
        args[#args] = lastArg .. "\n"
    elseif lastArg and type(lastArg) ~= "string" then
        args[#args + 1] = "\n"
    end

    if prefix and type(prefix) == "string" then
        MsgC(tll.colors.primary, "[" .. prefix .. "] ", tll.colors.white, unpack(args))
    else
        MsgC(tll.colors.white, unpack(args))
    end
end

--- Returns a plural noun.
--- @param num number @Number to check.
--- @param one string @A noun for number ending in 1.
--- @param two string @A noun for number ending in 2-4.
--- @param five string @A noun for number ending in 5+.
--- @return string
function tll.GetNoun(num, one, two, five)
    local n = math.abs(num) % 100;

    if n >= 5 and n <= 20 then
        return five;
    end

    n = n % 10;
    if n == 1 then
        return one;
    end

    if n >= 2 and n <= 4 then
        return two;
    end

    return five;
end

--- Validates a table against a schema.
--- Schema example:
--- * {
--- *     schemaStr = "string",
--- *     schemaFunc = "function",
--- *     schemaMultiType = { "string", "table" }
--- *     schemaCustomCheck = function(self) return isstring(self) or istable(self) end,
--- * }
--- @param schema table @The table validation schema.
--- @param validationTable table @The table to validate.
--- @param validationString table @String what table we are validating for ErrorNoHalt.
--- @return boolean @Whether the validation succeeded.
function tll.CheckTableValidation(schema, validationTable, validationString)
    local stackTrace = debug.traceback()
    local stackTraceStr = stackTrace:find("in main chunk")

    stackTraceStr = string.Explode("\n\t", stackTrace:sub(1, stackTraceStr - 3))
    stackTraceStr = stackTraceStr[#stackTraceStr]

    local errorText

    if type(schema) ~= "table" then
        errorText = "[TLL Error] Schema must be a table! [" .. stackTraceStr .. "]\n"
    end
    if table.Count(schema) == 0 then
        errorText = "[TLL Error] Schema must not be empty! [" .. stackTraceStr .. "]\n"
    end
    if type(validationTable) ~= "table" then
        errorText = "[TLL Error] Validation table must be a table! [" .. stackTraceStr .. "]\n"
    end
    if table.Count(validationTable) == 0 then
        errorText = "[TLL Error] Validation table must not be empty! [" .. stackTraceStr .. "]\n"
    end

    if errorText then
        ErrorNoHalt(errorText)
        return false
    end

    local isValid = true
    errorText = ("[TLL Error] Incorrect %s! [%s]\nInvalid elements:\n"):format(validationString or "table", stackTraceStr)

    for k, v in next, validationTable do
        local schemaValue = schema[k]
        local schemaValueType = type(schemaValue)
        local schemaValueIsFunc = schemaValueType == "function"

        local schemaTypeIsValid = false

        if schemaValueType == "table" then
            if #schemaValue == 0 then
                ErrorNoHalt("[TLL Error] '" .. k .. "' types not found! [" .. stackTraceStr .. "]\n")
                return false
            end

            for i = 1, #schemaValue do
                local value = schemaValue[i]
                local schemaType = tll.types[value]

                if not schemaType then
                    ErrorNoHalt("[TLL Error] Invalid type of '" .. k .. "'! '" .. value .. "' does not exist! [" .. stackTraceStr .. "]\n")
                    return false
                end

                if type(v) == schemaType then
                    schemaTypeIsValid = true
                end
            end
        elseif schemaValueType == "string" then
            local schemaType = tll.types[schemaValue]
            if not schemaType then
                ErrorNoHalt("[TLL Error] Invalid type of '" .. k .. "'! '" .. schemaValue .. "' does not exist! [" .. stackTraceStr .. "]\n")
                return false
            end

            schemaTypeIsValid = type(v) == schemaType
        end

        if not schemaTypeIsValid and not (schemaValueIsFunc and schemaValue(validationTable[k])) then
            local schemaType = schemaValueType == "table" and "(must be a " .. tll.tableToString(schemaValue) .. ")"
                                    or schemaValueType == "function" and ""
                                    or "(must be a " .. schemaValue .. ")"

            errorText = errorText .. ("\t- %s %s\n"):format(k, schemaType)
            isValid = false
        end
    end

    if not isValid then ErrorNoHalt(errorText) end
    return isValid
end

--- Removes all entities found by class.
--- @param class string @Entities class name.
function tll.RemoveAllByClass(class)
    local entities = ents.FindByClass(class)

    for i = 1, #entities do
        local ent = entities[i]
        if not IsValid(ent) then continue end

        ent:Remove()
    end
end

--- Returns a string of table elements separated by commas.
--- @param tbl table @The table to convert to string.
--- @param bSort bool @Whether to sort table.
--- @return string
function tll.TableToString(tbl, bSort)
    local tempTbl = tbl
    if bSort then table.sort(tempTbl) end

    local str = ""
    local tempTblLength = #tempTbl

    for i = 1, tempTblLength do
        str = str .. tempTbl[i] .. (i == tempTblLength and "" or ", ")
    end

    return str
end

--- Loads lua file from a path.
--- @param loadSide string | nil @Optional - SERVER, CLIENT or SHARED side.
--- @param directoryPath string @File path.
function tll.Load(loadSide, pathToFile)
    local lowerSide = string.lower(loadSide)
    local fileFound = file.Find(pathToFile, "LUA")

    if #fileFound == 0 then
        tll.Log("TLL", "Could not find file: ", tll.colors.path, pathToFile)
        return
    end

    if lowerSide == "server" and SERVER then
        tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
        include(pathToFile)
    elseif lowerSide == "client" then
        if SERVER then AddCSLuaFile(pathToFile) end
        if CLIENT then include(pathToFile) end
    elseif lowerSide == "shared" then
        if SERVER then
            AddCSLuaFile(pathToFile)
            tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
        end

        include(pathToFile)
    end
end

--- Loads all lua files from a directory.
--- @param loadSide string | nil @Optional - SERVER, CLIENT or SHARED side.
--- @param directoryPath string @Directory path.
function tll.LoadFiles(loadSide, directoryPath)
    local lowerSide = loadSide and string.lower(loadSide) or nil
    local files, directories = file.Find(directoryPath .. "/*", "LUA")

    for i = 1, #files do
        local fileName = files[i]
        local pathToFile = directoryPath .. "/" .. fileName

        if (lowerSide and lowerSide == "server") and SERVER then
            tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
            include(pathToFile)
        elseif (lowerSide and lowerSide == "client") then
            if SERVER then AddCSLuaFile(pathToFile) end
            if CLIENT then include(pathToFile) end
        elseif (lowerSide and lowerSide == "shared") then
            if SERVER then
                AddCSLuaFile(pathToFile)
                tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
            end

            include(pathToFile)
        else
            initFile(directoryPath, fileName)
        end
    end

    for i = 1, #directories do
        local directory = directories[i]
        local directoryFiles = file.Find(directoryPath .. "/" .. directory .. "/*.lua", "LUA")

        for j = 1, #directoryFiles do
            local directoryFile = directoryFiles[j]
            local pathToFile = directoryPath .. "/" .. directory .. "/" .. directoryFile

            if ((lowerSide and lowerSide == "server") or (not lowerSide and directory == "server")) and SERVER then
                tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
                include(pathToFile)
            elseif (lowerSide and lowerSide == "client") or (not lowerSide and directory == "client") then
                if SERVER then AddCSLuaFile(pathToFile) end
                if CLIENT then include(pathToFile) end
            elseif (lowerSide and lowerSide == "shared") then
                if SERVER then
                    AddCSLuaFile(pathToFile)
                    tll.Log("TLL", "Loading file: ", tll.colors.path, pathToFile)
                end

                include(pathToFile)
            else
                initFile(directoryPath, directoryFile)
            end
        end
    end
end

if CLIENT then
    --- Returns a number based on the size argument and your screen's height.
    --- The screen's height is always equal to size 1080.
    --- This function is primarily used for scaling font sizes.
    ---
    --- @param size number
    --- @return number
    function tll.ScreenScale(size)
        return math.ceil(size * (ScrH() / 1080))
    end
end

if SERVER then
    hook.Add("Initialize", "tll.CheckVersion", function()
        timer.Simple(0, function()
            http.Fetch("https://raw.githubusercontent.com/Tensitune/tll/master/version.txt",
                -- success
                function(body)
                    if (tonumber(string.Trim(body)) > version) then
                        tll.Log("TLL", tll.colors.warning, "You are not using the latest version of TLL!")
                        tll.Log("TLL", tll.colors.warning, "You can find the new version here: ", tll.colors.path, "https://github.com/Tensitune/tll")
                    end
                end,

                -- failure
                function()
                    tll.Log("TLL", tll.colors.warning, "Failed to check version")
                end
            )
        end)
    end)
end
