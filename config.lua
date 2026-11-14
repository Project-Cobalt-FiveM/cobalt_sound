---@class SoundConfig
---@field AllowedHosts string[] Hosts, and their subdomains, that URL sounds may stream from
---@field DefaultDistance number
---@field MaxDistance number
---@field ClientRange number How far from a requesting player a client may place a world sound
---@field ClientRequests { limit: integer, window: integer } Requests a player may make per window (ms)
---@field ClientLiveLimit integer Sounds one player's requests may have playing at once
---@field ClientLifetime number Seconds a world sound a client requested plays at most, looping or not
---@field UnknownDurationLimit number Seconds a non-looping sound lives when no client has reported its length

---@type SoundConfig
return {
    -- Streaming sounds from URLs
    AllowedHosts = {}, -- hosts URL sounds may stream from, e.g. { 'cdn.example.com' }; subdomains count; empty allows only files in sounds/

    -- World sound range
    DefaultDistance = 10.0, -- meters a world sound carries when the caller sets no distance
    MaxDistance = 100.0, -- largest distance a caller may set, in meters

    -- Sounds requested by clients
    ClientRange = 25.0, -- meters from the requesting player a client may place a world sound; also the most distance a client sound carries
    ClientRequests = { limit = 10, window = 10000 }, -- a player may request limit sounds per window milliseconds
    ClientLiveLimit = 5, -- most sounds one player's requests may have playing at once; they all stop when the player leaves or their character unloads
    ClientLifetime = 300, -- seconds a world sound a client requested plays at most, looping or not; a sound a client plays only for itself has no time limit

    -- Cleanup
    UnknownDurationLimit = 600, -- seconds a non-looping sound is kept when no client has reported its length
}
