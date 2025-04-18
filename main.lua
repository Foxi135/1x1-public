function clear(...)
	local t = {...}
	for i = 1, #t do
		if type(t[i]) == "string" then
			_G[t[i]] = nil
		end
	end
end
--love.system.openURL(love.filesystem.getSaveDirectory())
function showMessageBox(message, buttonlist)
	local result

	if data.AutoUiScale then
		data.uiScale = math.max(1,math.floor(math.min(love.graphics.getDimensions())/(12*40)*2)/2)
	
	end

	local w = 10
	local bw = w/#buttonlist
	local template
	if type(message) == "table" then
		template = {gridw=w,gridh=4,size=40,cascade={button={x=1,w=bw,h=1,padding=4,text_size=2}},align="center",
			{tag="label",label=(debug.getinfo(2, "S")).source,x=0,y=-1,text_size=1,w=w,h=3}
		}
		for k, v in pairs(message) do
			table.insert(template,{tag="label",label=v[1].."",x=0,y=k,text_size=(v.size or 2)+0,w=w,h=3,multiline=v.multiline and false or true})
		end
	else
		template = {gridw=w,gridh=4,size=40,cascade={button={x=1,w=bw,h=1,padding=4,text_size=2}},align="center",
			{tag="label",label=message.."",x=0,y=1,text_size=2,w=w,h=3},
			{tag="label",label=(debug.getinfo(2, "S")).source,x=0,y=-1,text_size=1,w=w,h=3}
		}
	end
	for k, v in pairs(buttonlist) do
		table.insert(template,{tag="button",label=v,y=3,x=bw*(k-1),clicked=function()
			result = k
		end})
	end
	local processed = ui.process(template)

	love.graphics.setShader(stripesShader)
	setColor(0,0,0,180/255)
	love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
	love.graphics.setShader()
	setColor(0,0,0,.5)
	love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
	setColor(1,1,1)
	ui.draw(processed)
	love.graphics.present()

	while true do
		love.event.pump()
		for name, a,b,c,d,e,f in love.event.poll() do
			if name == "quit" then
				if not love.quit or not love.quit() then
					QUIT = a or 0
					return
				end
			end
			if name == "keypressed" then
				if a == "escape" then
					result = false
					return
				end
			end
			if name == "mousepressed" then
				ui.mousepressed(processed,a,b,c,d)
			end
		end

		if result ~= nil then break end

		love.timer.sleep(1/20)
	end
	while love.event.pump() or love.mouse.isDown(1) do end
	return result
end

do
	function string.explode(str, delimiter)
		local result = {}
		local pattern = "([^" .. delimiter .. "]+)"
		for match in string.gmatch(str, pattern) do
			table.insert(result, match)
		end
		return result
	end
	local function handler(err)
		return debug.traceback("Error: " .. tostring(err), 2)
	end
	function safecall(func,...)
		local result = {xpcall(func,handler,...)}
		if result[1] then
			return unpack(result,2)
		else
			if showMessageBox({{"Something went wrong"},{string.explode(result[2],"\n")[1].."\n...",size=1}},{"Close",love.graphics.print(result[2]) or "Copy error and close"}) == 2 then
				love.system.setClipboardText(result[2])
			end
			parts.start("menu")
		end
	end
end


stripesShader = love.graphics.newShader([[
	float slope = 5.0;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
		float s = 1.0;
		if (color.a * 255.0 == 180.0) {
			color.a = 1.0;
			s = -1.0;
		}

		float modY = mod(screen_coords.y, slope);
		float posSum = screen_coords.x + modY * s;
		float i = mod(posSum, slope);

		if (i == 0.0) {
			return Texel(tex, texture_coords) * color;
		}
		return vec4(0.0);
	}
]])



function love.run()
	lovebird = require "lovebird"
	inspect = require "inspect"
	utf8 = require "utf8"
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

	do
		local t = { -- special input button
			1,2
		}
		local specialKeys = {}
		for k, v in pairs(t) do
			specialKeys[v] = utf8.char(0xe000 + k)
		end
		keyR = function(k)
			return specialKeys[k] or "["..string.upper(k or "this is a bug.. probably").."]"
		end
		returnSpecialSymbols = function()
			return specialKeys
		end
	end
	

	setColor = love.graphics.setColor
	love.graphics.setDefaultFilter("nearest","nearest")

	do
		local letters = " AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890.,:;!?#/\\()[]|-+*=~"..
				table.concat(returnSpecialSymbols())

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

		safecall(parts.entries[p].load,lastLoaded,arg)
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
		love.event.pump()
		for name, a,b,c,d,e,f in love.event.poll() do
			if name == "quit" then
				if not love.quit or not love.quit() then
					return a or 0
				end
			end
			love.handlers[name](a,b,c,d,e,f)
			if scene[name] then scene[name](a,b,c,d,e,f) end
			if scene.event then scene.event(name,a,b,c,d,e,f) end
		end

		dt = love.timer.step()
		lovebird:update()
		if data.AutoUiScale then
			data.uiScale = math.max(1,math.floor(math.min(love.graphics.getDimensions())/(12*40)*2)/2)
		end
		if scene.update then scene.update(dt) end

		if love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			
			if scene.draw then scene.draw() end
			if love.draw then love.draw() end

			love.graphics.present()
		end

		if QUIT then return QUIT end

		love.timer.sleep(0.001)
	end
end

function love.quit()
	love.filesystem.write("data.json",json.encode(data))
end