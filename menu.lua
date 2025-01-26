local buttonFuncs = {}

function buttonFuncs.openWorldView(hold)
    processed = {ui.process({gridw=10,gridh=13,size=40,cascade={button={padding=4,text_size=2,h=1},label={padding=4,text_size=2,h=1,align="center"}},align="center",
        {tag="label",label=hold.."",x=0,y=1,w=10},
        {tag="button",label="play",x=1,y=3,w=8,hold=hold.."",clicked=function(hold)
            menu = nil
            processed = nil
            parts.start("game",hold.."")
        end},
        {tag="button",label="delete",x=1,y=11,w=2,hold=hold.."",clicked=function(hold)
            if showMessageBox("Do you want to delete world "..hold.."?",{"No","Yes"}) == 2 then
                local folder = "worlds/"..hold.."/"
                for _, v in ipairs(love.filesystem.getDirectoryItems(folder)) do
                    love.filesystem.remove(folder..v)
                end
                love.filesystem.remove(folder)
                buttonFuncs.openWoldSelect()
            end
        end},
        {tag="button",label="back",x=5,y=11,w=4,clicked=buttonFuncs.openWoldSelect},
    })}
end

function buttonFuncs.openWoldSelect()
    local worlds = love.filesystem.getDirectoryItems("worlds")
    local result = {gridw=9,gridh=10,size=40,cascade={button={padding=4,text_size=2,x=0,w=9,h=1,clicked=buttonFuncs.openWorldView},label={text_size=2}},align="center",hide_overflow=true,scrollY=true,items_per_row=1}
    for k, v in pairs(worlds) do
        table.insert(result,{tag="button",label=v,y=k-1,hold=v})
    end
    processed = {ui.process(menu.worlds),ui.process(result)}
end

utils = require "game.utilities"
local function getData_loop(value,keys,setTo)
    local k = tonumber(keys[1]) or keys[1]
    if #keys == 1 then
        if setTo ~= nil then
            value[k] = setTo
            return
        end
        return value[k]
    end
    return getData_loop(value[k],table.remove(keys,1) and keys)
end
local function getData(path)
    local t = string.split(path,".")
    return getData_loop(data,t)
end
local function setData(path,value)
    local t = string.split(path,".")
    return getData_loop(data,t,value)
end

local function loadSettings(template)
    for k, v in pairs(template) do
        if tonumber(k) and v.tag == "cycle" then
            local d = getData(v.id)
            if type(d) == "boolean" then
                template[k].option = d and 1 or 2
            else
            end
        end
    end
    return template
end

function buttonFuncs.openSettings()
    processed = {ui.process(menu.settings),ui.process(loadSettings(menu.settingsScroll))}
end
local cyclelength = 10*60
local cyclestart = 0
local cycleoffset = 130

local seed = 0

local function randomLevel(i,limit)
    return math.floor(math.max((i+seed * 214743) % (i^2)%500,0))%limit
end

local bg
local function genBG()
    seed = love.timer.getTime()*50+0
    local ww,wh = love.graphics.getDimensions()
    local tileSize = 30
    local limit = 5
    local tiles = math.floor(ww/tileSize)
    local tileSize = ww/tiles
    bg = love.graphics.newCanvas(ww,wh)
    love.graphics.setCanvas(bg)
    love.graphics.push()
    love.graphics.translate(0,wh)
    love.graphics.scale(tileSize,-tileSize)
    local t = {}
    local s,e = 0-limit, tiles+limit
    for i = s,e do
        local y = randomLevel(i,limit)+1
        t[i] = y
    end
    for _ = 1, 9, 1 do
        for i = s,e do
            local a,b = t[i],(t[i+1] or 0)
            local d = (a-b)
            local r = math.abs(d)
            if r > 1 then
                t[i] = b+(d/r)
            end
        end
    end
    for i = 0,tiles do
        local a,b,c = t[i],(t[i+1] or 0),(t[i-1] or 0)
        if b==c and b~=a then
            t[i] = b
        end
    end
    for i = 0, tiles do
        setColor(0,0,0)
        love.graphics.rectangle("fill",i,t[i]+1,1,-limit-1)
        setColor(0.25,0.608,0.04)
        love.graphics.rectangle("fill",i,t[i],1,1)
    end
    love.graphics.pop()
    love.graphics.setCanvas()
end


local function constructWorld(option,world_name)
    local images = {}
    local map = {}

    local info = {stackLimit=99,mapSize=200,player={color={{0.4,0.4,1},{0.9,0.9,1}},inHand=4,cx=0,cy=0,inventory={},x=0,y=0}}


    local fixCoords = function(x,y,cx,cy)
        local ox,oy = math.floor(x/info.mapSize),math.floor(y/info.mapSize)
        local px,py = x%info.mapSize,y%info.mapSize
        local ncx,ncy = cx+ox,cy+oy
        return px,py,ncx,ncy
    end

    local draw = function()
        
    end


    local env = {
        print = print,
        ipairs = ipairs,
        pairs = pairs,

        info = info,

        importStructure = function(file)
            table.insert(images,love.graphics.newImage(option.."/"..file))
            local id = #images; local img = images[id]
            return {width=img:getWidth(),height=img:getHeight(),id=id+0}
        end,

        build = function(image,x,y,cx,cy)
            local _,_,minx,miny = fixCoords(x,y,cx,cy)
            local _,_,maxx,maxy = fixCoords(x+image.width,y+image.height,cx,cy)
            local s = info.mapSize
            for icx = minx, maxx, 1 do
                for icy = miny, maxy, 1 do
                    map[icx] = map[icx] or {}
                    map[icx][icy] = map[icx][icy] or love.graphics.newCanvas(s,s)
                    love.graphics.setCanvas(map[icx][icy])
                    setColor(1,1,1)
                    love.graphics.draw(images[image.id],math.floor(x+(cx-icx)*s),math.floor(y+(cy-icy)*s))
                    love.graphics.setCanvas()
                end
            end
        end,

        --[[test = function(x,y)
            if not x then
                print(inspect(map))
                return
            end
            print(inspect(map[x][y]))
            map[x][y]:newImageData():encode("png","TEST"..x.."_"..y..".png")
        end,]]


        fixCoords = fixCoords
    }
    setmetatable(env, {__index = nil})

    

    local func, err = loadstring(love.filesystem.read(option.."/construct.lua"))
    if not func then
        error("Error loading custom code: "..err)
    end
    setfenv(func, env)
    local success,runerr = pcall(func)
    if not success then
        error("Error executing custom code: "..runerr)
    end

    local folder = "worlds/"..world_name.."/"
    if not love.filesystem.getInfo(folder) then
        love.filesystem.createDirectory(folder)
    end

    love.filesystem.write(folder.."info.json",(json or require "json").encode(info))
    love.filesystem.write(folder.."entities",binser.serialize({}))
    for cx, c in pairs(map) do
        for cy, chunk in pairs(c) do
            map[cx][cy]:newImageData():encode("png",folder..cx.."_"..cy..".png")
        end
    end

end


function buttonFuncs.newWorld(hold)
    processed = {ui.process({gridw=10,gridh=13,size=40,cascade={button={padding=4,text_size=2,h=1},label={padding=4,text_size=2,h=1,align="center"},input={padding=4,h=1}},align="center",
        {tag="label",label=hold[1].."",x=0,y=1,w=10},
        {tag="label",label="name your new world:",x=0,y=3,w=10},
        {tag="input",label="",id="worldname",x=1,y=4,w=8},
        {tag="button",label="build",x=1,y=11,w=4,hold=hold[2].."",clicked=function(hold)
            local world_name = processed[1].dynamic.worldname.field.text
            if love.filesystem.getInfo("worlds/"..world_name) then
                if showMessageBox("World "..world_name.." already exist,\ndo you want to write over it?",{"No","Yes"}) == 2 then
                    for _, v in ipairs(love.filesystem.getDirectoryItems("worlds/"..world_name)) do
                        love.filesystem.remove("worlds/"..world_name.."/"..v)
                    end
                else
                    return
                end
            end
            constructWorld(hold,world_name)
            menu = nil
            processed = nil
            parts.start("game",world_name.."")
        end},
        
        {tag="button",label="back",x=5,y=11,w=4,clicked=buttonFuncs.openConstructSelect},
    })}
end

function buttonFuncs.openConstructSelect()
    local result = {gridw=9,gridh=10,size=40,cascade={button={padding=4,text_size=2,x=0,w=9,h=1,clicked=buttonFuncs.newWorld},label={text_size=2}},align="center",hide_overflow=true,scrollY=true,items_per_row=1}

    local max
    for k, v in pairs(love.filesystem.getDirectoryItems("default")) do
        local l = v.." (built-in)"
        table.insert(result,{tag="button",label=l,y=k-1,hold={l,"default/"..v}})
        max = k
    end
    if love.filesystem.getInfo("constructors") then
        for k, v in pairs(love.filesystem.getDirectoryItems("constructors")) do
            table.insert(result,{tag="button",label=v,y=k-1+max,hold={v,"constructors/"..v}})
        end
    end

    processed = {ui.process(menu.construct),ui.process(result)}
end


local fromIntro;

return {
    load = function(lastLoaded)        
        menu = {
            main = {gridw=10,gridh=10,size=40,cascade={button={x=1,w=8,h=1,padding=4,text_size=2}},align="center",
                {tag="button",label="worlds",y=6,clicked=buttonFuncs.openWoldSelect},
                {tag="button",label="settings",y=7,clicked=buttonFuncs.openSettings},
                {tag="button",label="exit",y=8,clicked=love.event.quit},
                {tag="image",src="ui/title.png",x=3,y=1,w=4,h=4,filter="linear"},
                {tag="label",label="test",x=0,y=0,text_size=1,w=3,h=3,id="fps"}
            },
            worlds = {gridw=11,gridh=14,size=40,cascade={button={padding=4,text_size=2,y=12,w=4,h=1},label={text_size=2}},align="center",
                --{tag="label",label="test",x=0,y=0,text_size=1,w=3,h=3,id="fps"},
                {tag="label",label="select a world",w=9,h=1,x=1,y=1,align="center"},
                {tag="button",label="back",x=6,clicked=function()
                    processed = {ui.process(menu.main)}
                end},
                {tag="button",label="new",x=1,clicked=buttonFuncs.openConstructSelect},
            },
            construct = {gridw=11,gridh=14,size=40,cascade={button={padding=4,text_size=2,y=12,w=4,h=1},label={text_size=2}},align="center",
                {tag="label",label="select a world constructor",w=9,h=1,x=1,y=1,align="center"},
                {tag="button",label="back",x=6,clicked=function()
                    processed = {ui.process(menu.worlds)}
                end},
            },
            settings = {gridw=11,gridh=14,size=40,cascade={button={padding=4,text_size=2,y=12,w=4,h=1},label={text_size=2}},align="center",
                {tag="label",label="settings",w=9,h=1,x=1,y=1,align="center"},
                {tag="button",label="back",x=6,clicked=function()
                    if showMessageBox("Do you want to exit settings?",{"No","Yes"}) == 2 then
                        processed = {ui.process(menu.main)}
                    end
                end},
                {tag="button",label="save and apply",x=1,clicked=function()
                    if showMessageBox("Do want to change the settings?",{"No","Yes"}) == 2 then
                        for k, v in pairs(menu.settingsScroll) do
                            if tonumber(k) and v.tag == "cycle" then
                                setData(v.id,(v.cycle or {true,false})[processed[2].dynamic[v.id].option])
                            end
                        end
                        love.filesystem.write("data.json",json.encode(data))

                        love.window.setVSync(data.vsync)
                        parts.entries.menu.resize(love.graphics.getDimensions())
                        love.window.setFullscreen(data.fullscreen)
                    end
                end},
            },
            settingsScroll = {gridw=10,gridh=10,size=40,cascade={button={padding=4,text_size=2,x=1,w=10,h=1},cycle={padding=4,text_size=2,x=1,w=10,h=1,cycle={true,false}},label={text_size=2,x=1,w=10,h=1}},align="center",hide_overflow=true,scrollY=true,
                {tag="label",label="visual",x=0,y=0,align="center"},
                {tag="cycle",label="Auto scale UI",x=0,y=1,text_size=2,w=10,h=1,id="AutoUiScale"},
                {tag="cycle",label="Fullscreen",x=0,y=2,text_size=2,w=5,h=1,id="fullscreen"},
                {tag="cycle",label="Vsync",x=5,y=2,text_size=2,w=5,h=1,id="vsync"},
            }
        }
        processed = {ui.process(menu.main)}

        cyclestart = love.timer.getTime()-cycleoffset

        fromIntro = lastLoaded == "intro"

        parts.entries.menu.resize(love.graphics.getDimensions())
    end,
    draw = function()

        local cover;
        do
            local daynightcycletime = love.timer.getTime()-cyclestart
            local fade = .5
            if daynightcycletime-cycleoffset<fade then
                cover = (fade-daynightcycletime+cycleoffset)/fade
            end
            local daynightcycle = math.abs(1-(daynightcycletime%cyclelength*2)/cyclelength)
            local c1 = {.5*daynightcycle,.7*daynightcycle,daynightcycle*.9+.1}
            local c2 = {1,.55,.25}
            local a = math.cos(daynightcycle*math.pi)
            local b = 1-math.max(0,(1-math.abs(a)-.5)*2)*.7
            love.graphics.clear((c1[1]-c2[1])*b+c2[1],(c1[2]-c2[2])*b+c2[2],(c1[3]-c2[3])*b+c2[3])

            setColor(daynightcycle,daynightcycle,daynightcycle)
            love.graphics.draw(bg)
        end

        setColor(1,1,1)
        
        for k, v in pairs(processed) do
            ui.draw(processed[k])
        end
        if cover and fromIntro then
            setColor(0,0,0,cover)
            love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
            setColor(1,1,1)
        end
    end,
    mousepressed = function(x,y,button,presscount)
        for k, v in pairs(processed) do
            ui.mousepressed(v,x,y,button,presscount)
        end
    end,
    update = function()
        if processed[1].dynamic.fps then -- dynamic label demo
            processed[1].dynamic.fps.label = love.timer.getFPS()
        end
    end,
    keypressed = function(key,scancode,isRepeat)
        for k, v in pairs(processed) do
            ui.keypressed(v,key,isRepeat)
        end
    end,
    mousereleased = function(x,y,button)
        for k, v in pairs(processed) do
            ui.mousereleased(v,x,y,button)
        end
    end,
    mousemoved = function(x,y)
        for k, v in pairs(processed) do
            ui.mousemoved(v,x,y)
        end
    end,
    wheelmoved = function(x,y)
        for k, v in pairs(processed) do
            ui.wheelmoved(v,x,y)
        end
    end,
    textinput = function(t)
        for k, v in pairs(processed) do
            ui.textinput(v,t)
        end
    end,
    resize = function(ww,wh)
        if data.AutoUiScale then
            data.uiScale = math.max(1,math.floor(math.min(ww,wh)/(10*40)))
        end
        genBG()
    end,
    close = function()
        
    end
}