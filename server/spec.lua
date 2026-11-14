local config <const> = require 'config'
local fileSource <const> = require 'shared.source'

---@class SoundSpec
---@field src string
---@field coords? vector3
---@field entity? integer
---@field player? integer
---@field bucket? integer Routing bucket a coords sound plays in
---@field volume number
---@field distance number
---@field falloff number
---@field loop boolean
---@field paused boolean
---@field offset number

local Spec <const> = {}

---@param url string
---@return string?
local function urlSource(url)
    if #url > 512 or url:find('[%s"\'<>\\@]') then return end

    local host, rest <const> = url:match('^https?://([%w%.%-]+)(.*)$')
    if not host or (rest ~= '' and not rest:find('^[/:?#]')) then return end

    host = host:lower()

    for _, allowed in ipairs(config.AllowedHosts) do
        if host == allowed or host:sub(-#allowed - 1) == '.' .. allowed then
            return url
        end
    end
end

---@param sound unknown
---@return string?
function Spec.source(sound)
    if type(sound) ~= 'string' then return end

    if sound:find('^https?://') then
        return urlSource(sound)
    end

    return fileSource(sound)
end

---@param value unknown
---@param min number
---@param max number
---@param default number
---@return number?
local function clamp(value, min, max, default)
    if value == nil then return default end
    if type(value) ~= 'number' or value ~= value then return end

    return math.min(math.max(value, min), max)
end

---@param value unknown
---@return vector3?
local function toCoords(value)
    local kind <const> = type(value)
    if kind ~= 'vector3' and kind ~= 'vector4' and kind ~= 'table' then return end

    local x <const>, y <const>, z <const> = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return end
    if math.abs(x) > 1e5 or math.abs(y) > 1e5 or math.abs(z) > 1e5 then return end

    return vec3(x, y, z)
end

---@param netId unknown
---@return boolean
function Spec.entityExists(netId)
    if math.type(netId) ~= 'integer' or netId <= 0 then return false end

    local entity <const> = NetworkGetEntityFromNetworkId(netId)

    return entity ~= 0 and DoesEntityExist(entity)
end

---@param playerId unknown
---@return boolean
local function playerTarget(playerId)
    if math.type(playerId) ~= 'integer' then return false end

    return playerId == -1 or DoesPlayerExist(tostring(playerId))
end

---@param data unknown
---@return SoundSpec? spec
---@return string? error
function Spec.parse(data)
    if type(data) ~= 'table' then
        return nil, 'data must be a table'
    end

    local src <const> = Spec.source(data.sound)

    if not src then
        return nil, 'sound must be a file in sounds/ or a URL on an allowed host'
    end

    local targets <const> = (data.coords ~= nil and 1 or 0) + (data.entity ~= nil and 1 or 0) + (data.player ~= nil and 1 or 0)

    if targets ~= 1 then
        return nil, 'give exactly one of coords, entity or player'
    end

    local coords <const> = data.coords ~= nil and toCoords(data.coords) or nil

    if data.coords ~= nil and not coords then
        return nil, 'coords must be a vector3'
    end

    if data.entity ~= nil and not Spec.entityExists(data.entity) then
        return nil, 'entity must be the network id of an existing entity'
    end

    if data.player ~= nil and not playerTarget(data.player) then
        return nil, 'player must be a connected player or -1'
    end

    if data.bucket ~= nil and (math.type(data.bucket) ~= 'integer' or data.bucket < 0) then
        return nil, 'bucket must be an integer of 0 or more'
    end

    local volume <const> = clamp(data.volume, 0, 1, 1)
    local distance <const> = clamp(data.distance, 1, config.MaxDistance, config.DefaultDistance)
    local falloff <const> = clamp(data.falloff, 0.1, 8, 1)
    local offset <const> = clamp(data.offset, 0, 86400, 0)

    if not volume or not distance or not falloff or not offset then
        return nil, 'volume, distance, falloff and offset must be numbers'
    end

    return {
        src = src,
        coords = coords,
        entity = data.entity,
        player = data.player,
        bucket = coords and (data.bucket or 0) or nil,
        volume = volume,
        distance = distance,
        falloff = falloff,
        loop = data.loop == true,
        paused = data.paused == true,
        offset = offset,
    }
end

return Spec
