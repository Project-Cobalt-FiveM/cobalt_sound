local config <const> = require 'config'
local Spec <const> = require 'server.spec'

---@class Sound : SoundSpec
---@field id integer
---@field owner? integer Player who requested it; only they may control it from the client
---@field resource? string Resource that created it through an export
---@field startedAt integer Server time (ms) at which `offset` was the playhead
---@field duration? number Seconds, the longest length reported by a client allowed to hear it
---@field expiresAt? integer Server time (ms) after which the sound stops, set for world sounds clients request
---@field listeners? table<integer, true> Players a world sound has been sent to

---@class SoundState
---@field id integer
---@field src string
---@field coords? vector3
---@field entity? integer
---@field volume number
---@field distance number
---@field falloff number
---@field loop boolean
---@field paused boolean
---@field position number Playhead in seconds when the state was sent

local Registry <const> = {}

local sounds <const> = {} ---@type table<integer, Sound>
local lastId = 0

local JOIN_MARGIN <const> = 30.0
local LEAVE_MARGIN <const> = 60.0

---@class ListenerPosition
---@field id integer
---@field coords vector3
---@field bucket integer

---@param sound Sound
---@return number
local function playhead(sound)
    local position = sound.offset

    if not sound.paused then
        position += (GetGameTimer() - sound.startedAt) / 1000
    end

    if sound.loop and sound.duration then
        position = position % sound.duration
    end

    return position
end

---@param sound Sound
local function rebase(sound)
    sound.offset = playhead(sound)
    sound.startedAt = GetGameTimer()
end

---@param sound Sound
---@return SoundState
local function state(sound)
    return {
        id = sound.id,
        src = sound.src,
        coords = sound.coords,
        entity = sound.entity,
        volume = sound.volume,
        distance = sound.distance,
        falloff = sound.falloff,
        loop = sound.loop,
        paused = sound.paused,
        position = playhead(sound),
    }
end

---@return ListenerPosition[]
local function playerPositions()
    local positions <const> = {}

    for _, id in ipairs(GetPlayers()) do
        local playerId <const> = tonumber(id) --[[@as integer]]
        local ped <const> = GetPlayerPed(playerId)

        if ped ~= 0 then
            positions[#positions + 1] = {
                id = playerId,
                coords = GetEntityCoords(ped),
                bucket = GetPlayerRoutingBucket(playerId),
            }
        end
    end

    return positions
end

---@param sound Sound
---@return vector3? coords
---@return integer? bucket
local function origin(sound)
    if sound.coords then return sound.coords, sound.bucket end

    local entity <const> = NetworkGetEntityFromNetworkId(sound.entity)
    if entity == 0 then return end

    return GetEntityCoords(entity), GetEntityRoutingBucket(entity)
end

---Sends a world sound to players in its bucket who came within its range and withdraws it from those who left; `resend` also refreshes everyone still listening.
---@param sound Sound
---@param positions ListenerPosition[]
---@param resend boolean
local function reach(sound, positions, resend)
    local at <const>, bucket <const> = origin(sound)
    local listeners <const> = sound.listeners --[[@as table<integer, true>]]
    local payload

    for _, player in ipairs(positions) do
        local distance <const> = at and player.bucket == bucket and #(player.coords - at) or math.huge
        local listening <const> = listeners[player.id]

        if listening and distance > sound.distance + LEAVE_MARGIN then
            listeners[player.id] = nil
            TriggerClientEvent('cobalt_sound:remove', player.id, sound.id)
        elseif (listening and resend) or (not listening and distance <= sound.distance + JOIN_MARGIN) then
            listeners[player.id] = true
            payload = payload or state(sound)
            TriggerClientEvent('cobalt_sound:set', player.id, payload)
        end
    end
end

---@param sound Sound
local function publish(sound)
    if sound.listeners then return reach(sound, playerPositions(), true) end

    TriggerClientEvent('cobalt_sound:set', sound.player or -1, state(sound))
end

---@param sound Sound
local function remove(sound)
    sounds[sound.id] = nil

    if not sound.listeners then
        return TriggerClientEvent('cobalt_sound:remove', sound.player or -1, sound.id, true)
    end

    for playerId in pairs(sound.listeners) do
        TriggerClientEvent('cobalt_sound:remove', playerId, sound.id, true)
    end

    if sound.owner and not sound.listeners[sound.owner] then
        TriggerClientEvent('cobalt_sound:remove', sound.owner, sound.id, true)
    end
end

---@param sound Sound
---@return boolean
local function finished(sound)
    if sound.entity and not Spec.entityExists(sound.entity) then return true end
    if sound.expiresAt and GetGameTimer() >= sound.expiresAt then return true end
    if sound.loop or sound.paused then return false end

    return playhead(sound) >= (sound.duration or config.UnknownDurationLimit)
end

---@param spec SoundSpec
---@param owner? integer
---@param resource? string
---@return integer
function Registry.create(spec, owner, resource)
    lastId += 1

    local sound <const> = spec --[[@as Sound]]
    sound.id = lastId
    sound.owner = owner
    sound.resource = resource
    sound.startedAt = GetGameTimer()
    sound.listeners = (sound.coords or sound.entity) and {} or nil
    sound.expiresAt = owner and sound.listeners and sound.startedAt + config.ClientLifetime * 1000 or nil
    sounds[sound.id] = sound

    publish(sound)

    return sound.id
end

---@param id unknown
---@return Sound?
function Registry.get(id)
    return sounds[id]
end

---@param id integer
---@return boolean
function Registry.stop(id)
    local sound <const> = sounds[id]
    if not sound then return false end

    remove(sound)

    return true
end

---@param id integer
---@return boolean
function Registry.pause(id)
    local sound <const> = sounds[id]
    if not sound or sound.paused then return false end

    rebase(sound)
    sound.paused = true
    publish(sound)

    return true
end

---@param id integer
---@return boolean
function Registry.resume(id)
    local sound <const> = sounds[id]
    if not sound or not sound.paused then return false end

    sound.paused = false
    sound.startedAt = GetGameTimer()
    publish(sound)

    return true
end

---@param id integer
---@param seconds number
---@return boolean
function Registry.seek(id, seconds)
    local sound <const> = sounds[id]
    if not sound or type(seconds) ~= 'number' or seconds ~= seconds then return false end

    sound.offset = math.min(math.max(seconds, 0), sound.duration or 86400)
    sound.startedAt = GetGameTimer()
    publish(sound)

    return true
end

---@param id integer
---@param volume number
---@return boolean
function Registry.setVolume(id, volume)
    local sound <const> = sounds[id]
    if not sound or type(volume) ~= 'number' or volume ~= volume then return false end

    sound.volume = math.min(math.max(volume, 0), 1)
    publish(sound)

    return true
end

---@param id integer
---@param loop boolean
---@return boolean
function Registry.setLoop(id, loop)
    local sound <const> = sounds[id]
    if not sound or type(loop) ~= 'boolean' then return false end

    rebase(sound)
    sound.loop = loop
    publish(sound)

    return true
end

---@param id integer
---@param duration number
function Registry.reportDuration(id, duration)
    local sound <const> = sounds[id]
    if not sound or type(duration) ~= 'number' or duration ~= duration then return end
    if duration < 0.05 or duration > 86400 or duration <= (sound.duration or 0) then return end

    sound.duration = duration
end

---Every sound the player should hold now: frontend sounds for them, and world sounds in their bucket within reach, which then count them as a listener.
---@param playerId integer
---@return SoundState[]
function Registry.audibleTo(playerId)
    local list <const> = {}
    local ped <const> = GetPlayerPed(playerId)
    local coords <const> = ped ~= 0 and GetEntityCoords(ped) or nil
    local bucket <const> = GetPlayerRoutingBucket(playerId)

    for _, sound in pairs(sounds) do
        if sound.listeners then
            local at <const>, soundBucket <const> = origin(sound)
            local inReach <const> = coords and at and #(coords - at) <= sound.distance + JOIN_MARGIN

            if soundBucket == bucket and (sound.listeners[playerId] or inReach) then
                sound.listeners[playerId] = true
                list[#list + 1] = state(sound)
            end
        elseif sound.player == -1 or sound.player == playerId then
            list[#list + 1] = state(sound)
        end
    end

    return list
end

---@param playerId integer
---@return integer
function Registry.countOwned(playerId)
    local count = 0

    for _, sound in pairs(sounds) do
        if sound.owner == playerId then count += 1 end
    end

    return count
end

---@param playerId integer
function Registry.stopOwnedBy(playerId)
    for _, sound in pairs(sounds) do
        if sound.owner == playerId then
            remove(sound)
        end
    end
end

---@param playerId integer
function Registry.forgetPlayer(playerId)
    for _, sound in pairs(sounds) do
        if sound.listeners then sound.listeners[playerId] = nil end

        if sound.player == playerId then
            sounds[sound.id] = nil
        elseif sound.owner == playerId then
            remove(sound)
        end
    end
end

---@param resource string
function Registry.forgetResource(resource)
    for _, sound in pairs(sounds) do
        if sound.resource == resource then
            remove(sound)
        end
    end
end

function Registry.sweep()
    local positions

    for _, sound in pairs(sounds) do
        if finished(sound) then
            remove(sound)
        elseif sound.listeners then
            positions = positions or playerPositions()
            reach(sound, positions, false)
        end
    end
end

return Registry
