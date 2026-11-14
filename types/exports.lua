---@meta

---@class SoundData
---@field sound string file in `sounds/` (`alert` or `alert.ogg`) or an http(s) URL on an allowed host
---@field coords? vector3
---@field entity? integer network id
---@field player? integer server id, or -1 for everyone
---@field bucket? integer routing bucket of a `coords` sound, default 0; an entity sound plays in the entity's bucket
---@field volume? number 0 to 1, default 1
---@field distance? number meters
---@field falloff? number curve exponent, 1 is linear
---@field loop? boolean
---@field paused? boolean
---@field offset? number seconds to start from

---@class CobaltSoundExports
local CobaltSoundExports = {}

---**Server.** Starts a sound with exactly one of `coords`, `entity` or `player`.
---@param data SoundData
---@return integer? id
---@return string? error
function CobaltSoundExports:Play(data) end

---**Client.** Asks the server to start a sound; the target must be near or be the local player, and a `coords` sound
---plays in the player's routing bucket. `distance` is capped at `ClientRange`. The sound stops when the calling resource
---stops, and a world sound also after `ClientLifetime` seconds.
---@param data SoundData
---@return integer|false id
---@return string? error
function CobaltSoundExports:Play(data) end

---**Server.** Plays a 2D sound for one player.
---@param target integer server id, or -1 for everyone
---@param sound string
---@param volume? number 0 to 1
---@return integer? id
---@return string? error
function CobaltSoundExports:PlayFrontend(target, sound, volume) end

---**Client.** Plays a file from `sounds/` locally with no id.
---@param sound string file in `sounds/`, as `name` or `name.ogg`
---@param volume? number 0 to 1
function CobaltSoundExports:PlayFrontend(sound, volume) end

---**Server.** Plays a 3D sound at a world position.
---@param coords vector3
---@param sound string
---@param volume? number 0 to 1
---@param distance? number meters
---@return integer? id
---@return string? error
function CobaltSoundExports:PlayAt(coords, sound, volume, distance) end

---**Client.** Asks the server to play a 3D sound at a world position.
---@param coords vector3
---@param sound string
---@param volume? number 0 to 1
---@param distance? number meters
---@return integer|false id
---@return string? error
function CobaltSoundExports:PlayAt(coords, sound, volume, distance) end

---**Server.** Plays a 3D sound that follows a networked entity.
---@param netId integer
---@param sound string
---@param volume? number 0 to 1
---@param distance? number meters
---@return integer? id
---@return string? error
function CobaltSoundExports:PlayOnEntity(netId, sound, volume, distance) end

---**Client.** Asks the server to play a 3D sound that follows a networked entity.
---@param netId integer
---@param sound string
---@param volume? number 0 to 1
---@param distance? number meters
---@return integer|false id
---@return string? error
function CobaltSoundExports:PlayOnEntity(netId, sound, volume, distance) end

---**Shared.** Stops a sound; on the client only sounds that player started.
---@param id integer
---@return boolean
function CobaltSoundExports:Stop(id) end

---**Shared.** Pauses a sound.
---@param id integer
---@return boolean
function CobaltSoundExports:Pause(id) end

---**Shared.** Resumes a paused sound.
---@param id integer
---@return boolean
function CobaltSoundExports:Resume(id) end

---**Shared.** Moves a sound's playhead.
---@param id integer
---@param seconds number
---@return boolean
function CobaltSoundExports:Seek(id, seconds) end

---**Shared.** Sets a sound's volume.
---@param id integer
---@param volume number 0 to 1
---@return boolean
function CobaltSoundExports:SetVolume(id, volume) end

---**Shared.** Turns looping on or off.
---@param id integer
---@param loop boolean
---@return boolean
function CobaltSoundExports:SetLoop(id, loop) end

exports.cobalt_sound = CobaltSoundExports
