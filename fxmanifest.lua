fx_version "cerulean"
lua54 "yes"
game "gta5"

author "Subj3ct"

ui_page 'web/build/index.html'

files {
    "modules/*.lua",
	"web/build/index.html",
	"web/build/assets/*",
}

shared_scripts {
    "@ox_lib/init.lua",
    "modules/config.lua",
    "modules/utils.lua",
}

client_scripts {
    "client/client.lua",
}

server_scripts {
    "server/server.lua",
}

dependencies {
    'ox_inventory',
    'qbx_core',
    'ox_lib'
}
