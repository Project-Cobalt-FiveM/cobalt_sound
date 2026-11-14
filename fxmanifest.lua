fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'cobalt_sound'
author 'Project Cobalt'
description 'Server-authoritative 3D and 2D audio with late-join sync'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_script '@ox_lib/init.lua'
client_script 'client/init.lua'
server_script 'server/init.lua'

ui_page '_nui/build/index.html'

files {
    'client/*.lua',
    'shared/*.lua',
    '_nui/build/index.html',
    '_nui/build/assets/*',
    'sounds/*',
}
