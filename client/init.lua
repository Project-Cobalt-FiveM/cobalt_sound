---@class ClientSound : SoundState
---@field receivedAt integer
---@field loaded? boolean

local fileSource <const> = require 'shared.source'

local UNLOAD_MARGIN <const> = 5.0

local sounds <const> = {} ---@type table<integer, ClientSound>
local reported <const> = {} ---@type table<integer, true>
local requestedBy <const> = {} ---@type table<integer, string> resource that asked for each sound this client requested
local running = false

---@param sound ClientSound
---@return number
local function playhead(sound)
    if sound.paused then return sound.position end

    return sound.position + (GetGameTimer() - sound.receivedAt) / 1000
end

---@param sound ClientSound
local function payload(sound)
    return {
        id = sound.id,
        src = sound.src,
        volume = sound.volume,
        distance = sound.distance,
        falloff = sound.falloff,
        loop = sound.loop,
        paused = sound.paused,
        position = playhead(sound),
        spatial = sound.coords ~= nil or sound.entity ~= nil,
    }
end

---@param sound ClientSound
---@return vector3?
local function origin(sound)
    if sound.coords then return sound.coords end
    if not NetworkDoesNetworkIdExist(sound.entity) then return end

    local entity <const> = NetworkGetEntityFromNetworkId(sound.entity)

    return DoesEntityExist(entity) and GetEntityCoords(entity) or nil
end

---@param sound ClientSound
local function load(sound)
    sound.loaded = true
    SendNUIMessage({ action = 'load', sound = payload(sound) })
end

---@param sound ClientSound
local function unload(sound)
    sound.loaded = nil
    SendNUIMessage({ action = 'unload', id = sound.id })
end

---@return number[] forward
---@return number[] up
local function cameraAxes()
    local rotation <const> = GetFinalRenderedCamRot(2)
    local pitch <const>, yaw <const> = math.rad(rotation.x), math.rad(rotation.z)
    local sinPitch <const>, cosPitch <const> = math.sin(pitch), math.cos(pitch)
    local sinYaw <const>, cosYaw <const> = math.sin(yaw), math.cos(yaw)

    return { -sinYaw * cosPitch, cosYaw * cosPitch, sinPitch }, { sinYaw * sinPitch, -cosYaw * sinPitch, cosPitch }
end

---@return boolean spatial Whether a world sound is loaded
local function sync()
    local camera <const> = GetFinalRenderedCamCoord()
    local sources <const> = {}

    for _, sound in pairs(sounds) do
        if not sound.coords and not sound.entity then
            if not sound.loaded then load(sound) end
        else
            local position <const> = origin(sound)
            local distance <const> = position and #(position - camera)

            if distance and distance <= sound.distance then
                if not sound.loaded then load(sound) end
            elseif sound.loaded and (not distance or distance > sound.distance + UNLOAD_MARGIN) then
                unload(sound)
            end

            if sound.loaded and position then
                sources[#sources + 1] = { sound.id, position.x, position.y, position.z }
            end
        end
    end

    if #sources == 0 then return false end

    local forward <const>, up <const> = cameraAxes()

    SendNUIMessage({
        action = 'frame',
        listener = { position = { camera.x, camera.y, camera.z }, forward = forward, up = up },
        sources = sources,
    })

    return true
end

---@param state SoundState
local function store(state)
    local sound <const> = state --[[@as ClientSound]]
    local previous <const> = sounds[sound.id]

    sound.receivedAt = GetGameTimer()
    sound.loaded = previous and previous.loaded
    sounds[sound.id] = sound

    if sound.loaded then
        SendNUIMessage({ action = 'update', sound = payload(sound) })
    elseif running then
        sync()
    end
end

RegisterNetEvent('cobalt_sound:set', store)

---@param id integer
---@param ended? boolean The sound ended, rather than leaving this player's range
local function discard(id, ended)
    if ended then requestedBy[id] = nil end

    local sound <const> = sounds[id]
    if not sound then return end

    if sound.loaded then unload(sound) end

    sounds[id] = nil
    reported[id] = nil
end

RegisterNetEvent('cobalt_sound:remove', discard)

RegisterNUICallback('ready', function(_, cb)
    cb(true)

    if running then return end

    running = true

    CreateThread(function()
        for _, state in ipairs(lib.callback.await('cobalt_sound:snapshot', false) or {}) do
            store(state)
        end

        while true do
            Wait(sync() and 100 or 500)
        end
    end)
end)

RegisterNUICallback('duration', function(data, cb)
    cb(true)

    local id <const> = data.id
    if not sounds[id] or reported[id] then return end

    reported[id] = true
    TriggerServerEvent('cobalt_sound:duration', id, data.duration)
end)

---@param action string
---@param ... unknown
---@return unknown
local function request(action, ...)
    return lib.callback.await('cobalt_sound:request', false, action, ...)
end

---@param data SoundData
---@return integer|false id
---@return string? error
local function play(data)
    local resource <const> = GetInvokingResource() or cache.resource
    local id <const>, err <const> = request('play', data)

    if id then requestedBy[id] = resource end

    return id, err
end

exports('Play', play)

---@param coords vector3
---@param sound string
---@param volume? number
---@param distance? number
---@return integer|false id
---@return string? error
exports('PlayAt', function(coords, sound, volume, distance)
    return play({ sound = sound, coords = coords, volume = volume, distance = distance })
end)

---@param netId integer
---@param sound string
---@param volume? number
---@param distance? number
---@return integer|false id
---@return string? error
exports('PlayOnEntity', function(netId, sound, volume, distance)
    return play({ sound = sound, entity = netId, volume = volume, distance = distance })
end)

---@param sound string A file in `sounds/`, as `name` or `name.ogg`
---@param volume? number
exports('PlayFrontend', function(sound, volume)
    if type(sound) ~= 'string' then return end

    local src <const> = fileSource(sound)
    if not src then return end

    SendNUIMessage({
        action = 'frontend',
        src = src,
        volume = math.min(math.max(tonumber(volume) or 1, 0), 1),
    })
end)

---@param id integer
---@return boolean
exports('Stop', function(id)
    return request('stop', id)
end)

---@param id integer
---@return boolean
exports('Pause', function(id)
    return request('pause', id)
end)

---@param id integer
---@return boolean
exports('Resume', function(id)
    return request('resume', id)
end)

---@param id integer
---@param seconds number
---@return boolean
exports('Seek', function(id, seconds)
    return request('seek', id, seconds)
end)

---@param id integer
---@param volume number
---@return boolean
exports('SetVolume', function(id, volume)
    return request('setVolume', id, volume)
end)

---@param id integer
---@param loop boolean
---@return boolean
exports('SetLoop', function(id, loop)
    return request('setLoop', id, loop)
end)

AddEventHandler('onClientResourceStop', function(resource)
    local ids <const> = {}

    for id, owner in pairs(requestedBy) do
        if owner == resource then
            ids[#ids + 1] = id
            requestedBy[id] = nil
        end
    end

    if #ids > 0 then TriggerServerEvent('cobalt_sound:release', ids) end
end)
