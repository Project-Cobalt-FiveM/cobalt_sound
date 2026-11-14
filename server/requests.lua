local config <const> = require 'config'
local Spec <const> = require 'server.spec'
local Registry <const> = require 'server.registry'

local buckets <const> = {} ---@type table<integer, { resetAt: integer, count: integer }>

---@param playerId integer
---@return boolean
local function withinRate(playerId)
    local now <const> = GetGameTimer()
    local bucket <const> = buckets[playerId]

    if not bucket or now >= bucket.resetAt then
        buckets[playerId] = { resetAt = now + config.ClientRequests.window, count = 1 }
        return true
    end

    bucket.count += 1

    return bucket.count <= config.ClientRequests.limit
end

---@param playerId integer
---@param coords vector3
---@return boolean
local function nearPlayer(playerId, coords)
    return #(GetEntityCoords(GetPlayerPed(playerId)) - coords) <= config.ClientRange
end

---@param playerId integer
---@param spec SoundSpec
---@return boolean
local function allowedTarget(playerId, spec)
    if spec.player then return spec.player == playerId end
    if spec.coords then return nearPlayer(playerId, spec.coords) end

    local entity <const> = NetworkGetEntityFromNetworkId(spec.entity)
    if GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(playerId) then return false end

    return nearPlayer(playerId, GetEntityCoords(entity))
end

---@param playerId integer
---@param data unknown
---@return integer|false id
---@return string? error
local function play(playerId, data)
    local spec <const>, err <const> = Spec.parse(data)
    if not spec then
        return false, err
    end

    if not allowedTarget(playerId, spec) then
        return false, 'target is out of your reach'
    end

    if Registry.countOwned(playerId) >= config.ClientLiveLimit then
        return false, 'too many of your sounds are playing'
    end

    spec.distance = math.min(spec.distance, config.ClientRange)
    spec.bucket = spec.coords and GetPlayerRoutingBucket(playerId) or nil

    return Registry.create(spec, playerId)
end

local controls <const> = {
    stop = Registry.stop,
    pause = Registry.pause,
    resume = Registry.resume,
    seek = Registry.seek,
    setVolume = Registry.setVolume,
    setLoop = Registry.setLoop,
}

lib.callback.register('cobalt_sound:request', function(source, action, id, value)
    if not withinRate(source) then
        return false, 'too many sound requests'
    end

    if action == 'play' then
        return play(source, id)
    end

    local control <const> = controls[action]
    local sound <const> = Registry.get(id)
    if not control or not sound or sound.owner ~= source then return false end

    return control(id, value)
end)

lib.callback.register('cobalt_sound:snapshot', function(source)
    return Registry.audibleTo(source)
end)

---@param playerId integer
---@param sound Sound
---@return boolean
local function mayReportDuration(playerId, sound)
    if sound.owner == playerId then return true end
    if sound.player then return sound.player == -1 or sound.player == playerId end
    if not sound.coords and not sound.entity then return false end

    local at <const> = sound.coords or GetEntityCoords(NetworkGetEntityFromNetworkId(sound.entity))

    return #(GetEntityCoords(GetPlayerPed(playerId)) - at) <= sound.distance
end

RegisterNetEvent('cobalt_sound:duration', function(id, duration)
    local sound <const> = Registry.get(id)
    if not sound or not mayReportDuration(source, sound) then return end

    Registry.reportDuration(id, duration)
end)

RegisterNetEvent('cobalt_sound:release', function(ids)
    if type(ids) ~= 'table' then return end

    local source <const> = source

    for index = 1, math.min(#ids, config.ClientLiveLimit) do
        local id <const> = ids[index]

        if Registry.get(id)?.owner == source then Registry.stop(id) end
    end
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', Registry.stopOwnedBy)

AddEventHandler('playerDropped', function()
    buckets[source] = nil
    Registry.forgetPlayer(source)
end)
