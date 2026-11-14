local Spec <const> = require 'server.spec'
local Registry <const> = require 'server.registry'

require 'server.requests'

---@param data SoundData
---@return integer? id
---@return string? error
local function play(data)
    local spec <const>, err <const> = Spec.parse(data)
    if not spec then
        return nil, err
    end

    return Registry.create(spec, nil, GetInvokingResource())
end

exports('Play', play)

---@param target integer Server id, or -1 for everyone
---@param sound string
---@param volume? number
---@return integer? id
---@return string? error
exports('PlayFrontend', function(target, sound, volume)
    return play({ sound = sound, player = target, volume = volume })
end)

---@param coords vector3
---@param sound string
---@param volume? number
---@param distance? number
---@return integer? id
---@return string? error
exports('PlayAt', function(coords, sound, volume, distance)
    return play({ sound = sound, coords = coords, volume = volume, distance = distance })
end)

---@param netId integer
---@param sound string
---@param volume? number
---@param distance? number
---@return integer? id
---@return string? error
exports('PlayOnEntity', function(netId, sound, volume, distance)
    return play({ sound = sound, entity = netId, volume = volume, distance = distance })
end)

exports('Stop', Registry.stop)
exports('Pause', Registry.pause)
exports('Resume', Registry.resume)
exports('Seek', Registry.seek)
exports('SetVolume', Registry.setVolume)
exports('SetLoop', Registry.setLoop)

SetInterval(Registry.sweep, 1000)

AddEventHandler('onResourceStop', Registry.forgetResource)
