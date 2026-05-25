fx_version 'cerulean'
game 'gta5'

name 'horizon-skill-tree'
author 'meklasdev'
description 'Rozbudowane drzewko umiejętności ESX'
version '1.0.0'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_script 'config.lua'

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
