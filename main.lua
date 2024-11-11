function clear(...)
	local t = {...}
	for i = 1, #t do
		if type(t[i]) == "string" then
			_G[t[i]] = nil
		end
	end
end
function love.run()
	lovebird = require "lovebird"
	inspect = require "inspect"
	json = require "json"
	binser = require "binser"
	InputField = require "InputField"

	ui = require "ui"
	if type(ui) == "boolean" then -- sometimes returned boolean.. huh?
		love.event.quit("restart")
	end

	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	if love.timer then love.timer.step() end

	local dt = 0

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
            snap = "0",
            save = "f5",
            appdata = "f6",
            slot1 = "1",
            slot2 = "2",
            slot3 = "3",
            slot4 = "4",
            slot5 = "5",
            lockDirection = "lshift"
        }
	}
	
	if not love.filesystem.getInfo("data.json") then
		love.filesystem.write("data.json",json.encode(data))
	end

	setColor = love.graphics.setColor
	love.graphics.setDefaultFilter("nearest","nearest")

	do
		local letters = " AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890,.:;!?#/\\|-+*=~"
		local extraspacing = 1

		local imgData = love.image.newImageData("font/main.png")
		local img = love.graphics.newImage("font/main.png")

		font = love.graphics.newImageFont(imgData,letters,extraspacing)
		fh = font:getHeight()
		love.graphics.setFont(font)

		local canvas = love.graphics.newCanvas(img:getWidth()*2,img:getHeight()*2)
		love.graphics.setCanvas(canvas)
		love.graphics.draw(img,0,0,nil,2)
		love.graphics.setCanvas()

		font2 = love.graphics.newImageFont(canvas:newImageData(),letters,extraspacing*2)
		fh2 = font2:getHeight()
	end
	
	local scene
	parts = {}
	parts.entries = {
		game = require "game",
		menu = require "menu",
		intro = require "intro",
	}
	function parts.start(p,arg)
		local lastLoaded = parts.loaded and parts.loaded..""
		if parts.loaded and parts.entries[parts.loaded].close then
			parts.entries[parts.loaded].close()
		end
		parts.loaded = p
		parts.entries[p].load(lastLoaded,arg)
		scene = parts.entries[parts.loaded]
	end


	lovebird:init()

	parts.start("intro")

	--[[love.filesystem.write("0_-1.bin",binser.serialize(
		{
			entities = {
				{id="testentity",x=2,y=200}
			}
		}
	))]]

	return function()
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
				if scene[name] then scene[name](a,b,c,d,e,f) end
			end
		end

		if love.timer then dt = love.timer.step() end
		lovebird:update()
		if scene.update then scene.update(dt) end

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if scene.draw then scene.draw() end

			love.graphics.present()
		end

		if QUIT then return QUIT end

		if love.timer then love.timer.sleep(0.001) end
	end
end

function love.quit()
	love.filesystem.write("data.json",json.encode(data))
end