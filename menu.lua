local buttonFuncs = {}

function buttonFuncs.openWorldView(hold)
    processed = {ui.process({gridw=10,gridh=13,size=40,cascade={button={padding=4,text_size=2,h=1},label={padding=4,text_size=2,h=1,align="center"}},align="center",
        {tag="label",label=hold.."",x=0,y=1,w=10},
        {tag="button",label="play",x=1,y=3,w=8,hold=hold.."",clicked=function(hold)
            menu = nil
            processed = nil
            parts.start("game",hold.."")
            print(parts.loaded)
        end},
        {tag="button",label="delete",x=1,y=11,w=2},
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
function buttonFuncs.openSettings()
    processed = {ui.process(menu.settings),ui.process(menu.settingsScroll)}
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
                {tag="button",label="new",x=1},
            },
            settings = {gridw=11,gridh=14,size=40,cascade={button={padding=4,text_size=2,y=12,w=4,h=1},label={text_size=2}},align="center",
                {tag="label",label="settings",w=9,h=1,x=1,y=1,align="center"},
                {tag="button",label="back",x=6,clicked=function()
                    processed = {ui.process(menu.main)}
                end},
                {tag="button",label="apply",x=1,clicked=function()
                    processed = {ui.process(menu.main)}
                end},
            },
            settingsScroll = {gridw=11,gridh=10,size=40,cascade={button={padding=4,text_size=2,x=1,w=9,h=1,clicked=buttonFuncs.openWorldView},label={text_size=2,x=1,w=9,h=1}},align="center",hide_overflow=true,scrollY=true,
                {tag="label",label="video",x=1,y=0,align="center"},
                {tag="input",label="hello",x=1,y=1,align="center",text_size=2,w=9,h=1,id="textinputtest",padding=5},
            }
        }
        processed = {ui.process(menu.main)}

        cyclestart = love.timer.getTime()-cycleoffset

        print(lastLoaded)
        fromIntro = lastLoaded == "intro"

        genBG()
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
        --love.graphics.print("Menu")
        
        for k, v in pairs(processed) do
            ui.draw(processed[k])
        end
        if cover and fromIntro then
            setColor(0,0,0,cover)
            love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
            setColor(1,1,1)
        end
    end,
    update = function()
        if processed[1].dynamic.fps then -- dynamic label demo
            processed[1].dynamic.fps.label = love.timer.getFPS()
        end
    end,
    mousepressed = function(x,y,button,presscount)
        for k, v in pairs(processed) do
            ui.mousepressed(v,x,y,button,presscount)
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
    resize = function()
        genBG()
    end,
    close = function()
        
    end
}