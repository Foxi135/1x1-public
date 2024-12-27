data = {
	keyBinding = {
        up = "w",
        down = "s",
        left = "a",
        right = "d",
        sprint = "lshift",
        esc = "escape",
        inventory = "e",
        console = "c",
        place = 1,
        unplace = 2,
        save = "f5",
        appdata = "f6",
        slot1 = "1",
        slot2 = "2",
        slot3 = "3",
        slot4 = "4",
        slot5 = "5",
        rotate = "lshift"
    },
	swingLen = .4,
	swingAngle = .25,
	handLen = .4,
	uiScale = 1,
	AutoUiScale = false,
	fullscreen = false,
    vsync = false
}

local identity = "1x1-tenony2"
love.filesystem.setIdentity(identity)
local json = require "json"
if love.filesystem.getInfo("data.json") then
	data = json.decode(love.filesystem.read("data.json"))
else
	love.filesystem.write("data.json",json.encode(data))
end

function love.conf(t)
    t.window.resizable = true
    t.console = true
    t.window.msaa = 0
    t.window.width = 700
    t.window.height = 600
    t.window.vsync = data.vsync
    t.window.fullscreen = data.fullscreen

    t.window.minwidth = 550
    t.window.minheight = 550

    t.window.title = "1x1"
    t.window.icon = "icon.png"
    t.version = "11.5"
    t.identity = identity
end


