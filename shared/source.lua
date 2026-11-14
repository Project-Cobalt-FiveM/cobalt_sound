local resource <const> = cache.resource
local extensions <const> = { ogg = true, mp3 = true, wav = true, webm = true, m4a = true }
local knownFiles <const> = {} ---@type table<string, true>
local MAX_NAME_LENGTH <const> = 64

---Resolves a file in `sounds/`, given as `name` (`.ogg` assumed) or `name.ext`, to its NUI URL.
---@param name string
---@return string?
return function(name)
    if not name:find('.', 1, true) then
        name = name .. '.ogg'
    end

    if #name > MAX_NAME_LENGTH then return end

    local ext <const> = name:match('^[%w_%-]+%.(%w+)$')
    if not ext or not extensions[ext:lower()] then return end

    if not knownFiles[name] and LoadResourceFile(resource, 'sounds/' .. name) then
        knownFiles[name] = true
    end

    return knownFiles[name] and ('https://cfx-nui-%s/sounds/%s'):format(resource, name) or nil
end
