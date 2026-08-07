if shared.requirecheck then return end

local cloneref = cloneref or function(obj)
    return obj
end 

local HttpService = cloneref(game:GetService('HttpService'))
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

local xenoPste
do
	local res = request({
	    Url = 'https://httpbin.org/get',
	    Method = 'GET',
	    Headers = {
	        ['Content-Type'] = 'application/json'
	    }
	})
	
	if res.Success then
	    local data = HttpService:JSONDecode(res.Body)
	    for i,v in data.headers do
	        if string.find(i, 'Xeno') then
				xenoPste = true
	        end
	    end
	end
end

do
    local suc, res = pcall(function()
		return require(lplr.PlayerScripts.PlayerModule).controls
	end)

    if suc and not xenoPste then
        return
    end

    shared.requirecheck = true -- meant for poop execs so we don't override the function again..
end

local base64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64encode(data)
    return ((data:gsub('.', function(x)
        local r,bits='',x:byte()
        for i=8,1,-1 do
            r=r..(bits%2^i-bits%2^(i-1)>0 and '1' or '0')
        end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do
            c=c + (x:sub(i,i)=='1' and 2^(6-i) or 0)
        end
        return base64:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

do
    getgenv().decompile = function(scriptPath: ModuleScript | LocalScript): string
        local okBytecode: boolean, bytecode: string = pcall(getscriptbytecode, scriptPath)

        if not okBytecode then
            return `-- Failed to get script bytecode, error:\n\n--[[\n{bytecode}\n--]]`
        end

        local okRequest: boolean, httpResult = pcall(request, {
            Url = 'https://api.lua.expert/decompile',
            Method = 'POST',
            Body = HttpService:JSONEncode({
                script = base64encode(bytecode),
            }),
            Headers = {
                ['Content-Type'] = 'application/json'
            },
        })

        if not okRequest then
            return `-- Failed to decompile, error:\n\n--[[\n{httpResult}\n--]]`
        end

        if httpResult.StatusCode ~= 200 then
            return `-- Error occurred while requesting the API, error:\n\n--[[\n{httpResult.Body}\n--]]`
        end

        return string.gsub(httpResult.Body, string.char(0x00CD), ' ')
    end
end

do
    local function wrapInst(path) -- waitforchild garbage
        return setmetatable({}, {
            __index = function(_, key)
                if key == 'WaitForChild' then
                    return function(_, child, timeout)
                        timeout = timeout or 0

                        task.delay(timeout, function()
                            if instance:FindFirstChild(child) then
                                return wrap(instance:FindFirstChild(child))
                            end

                            if instance:IsA('ModuleScript') then
                                return script.Parent
                            else
                                return nil
                            end
                        end)
                    end
                end

                local value = instance[key]
                if typeof(value) == 'Instance' then
                    return wrap(value)
                end

                return value
            end
        })
    end

    getgenv().require = function(path: Instance)
        if not path or (path and not path:IsA('ModuleScript')) then
            return error('Attempted to call require with invalid arguments')
        end

        if not getscriptbytecode or not loadstring then -- we will just do this for execs which don't have getscriptbytecode and loadstring..
            return error('Requested module experienced an error while loading')
        end

        local source = decompile(path)
        local func = loadstring(source)

        getfenv(func).require = getgenv().require
        getfenv(func).script = wrapInst(path) -- waitforchild garbage, bedwars uses invalid paths breaking the script..
        getfenv(func).error = function() return nil end -- prevent scripts from leaking into the environment, detecting kool aid..

        local suc, res = pcall(function()
            return func()
        end)

        if suc and res ~= nil then
            return res
        else
            return error('Requested module experienced an error while loading')
        end
    end
end
