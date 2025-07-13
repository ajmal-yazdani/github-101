local cjson = require "cjson"
local io = require "io"

local function load_api_keys()
    local keys = {}
    local keys_dir = "/etc/api-keys"
    local pfile = io.popen('ls -1 "' .. keys_dir .. '" 2>/dev/null')
    if pfile then
        for filename in pfile:lines() do
            local filepath = keys_dir .. "/" .. filename
            local file = io.open(filepath, "r")
            if file then
                local key = file:read("*all")
                key = key:gsub("^%s*(.-)%s*$", "%1")
                if key and key ~= "" then
                    table.insert(keys, key)
                end
                file:close()
            end
        end
        pfile:close()
    end
    return keys
end

local function validate_api_key(api_key)
    local valid_keys = load_api_keys()
    for _, valid_key in ipairs(valid_keys) do
        if api_key == valid_key then return true end
    end
    return false
end

local api_key = ngx.req.get_headers()["X-API-Key"]
if not api_key then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "API key required"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

if not validate_api_key(api_key) then
    ngx.status = 401
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({error = "Invalid API key"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

ngx.req.set_header("X-API-Key", api_key)
