
love.keyboard.setKeyRepeat(true)

function saveWorld(level,folder)
    local player = level.entities[playerID]
    local info = {
        mapSize = level.mapSize,
        player = {
            x=player.x,y=player.y,cx=player.cx,cy=player.cy,
            color = level.player.color --entityColor.getColor(level.entities[playerID].color)
        },
    }
    local entities = {}
    for k, v in pairs(level.entities) do
        if (not k == playerID) and v.permanent then
            table.insert(entities,v)
        end
    end
    love.filesystem.write(folder.."entities",binser.serialize(entities))
    love.filesystem.write(folder.."info.json",json.encode(info))

    for _, v in ipairs(love.filesystem.getDirectoryItems("temp")) do
        local ext = v:match("^.+%.(.+)$")
        if not ext then
            love.image.newImageData("temp/"..v):encode("png",folder..v..".png")
        elseif ext == "bin" then
            local file love.filesystem.read("temp/"..v)
            file = binser:decode(file)
            if file.data then
                print("bah") -- todo
            end
        end
    end
    for cx, c in pairs(level.chunks) do
        for cy, chunk in pairs(c) do

            if level.chunks[cx][cy].modified then
                level.chunks[cx][cy].map:encode("png",folder..cx.."_"..cy..".png")
            end

        end
    end

end

local funnypauseshader = love.graphics.newShader([[    
    #pragma language glsl3
    uniform ivec2 dimensions;

    int slope = 5;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec4 p = Texel(tex, texture_coords);
        ivec2 pos = ivec2(texture_coords*dimensions);
        int i = (pos.x+(pos.y%slope))%slope;
        if (i == 0) {
            return vec4(0,0,0,0);
        }
        return p*vec4(0.5,0.5,0.5,1);
    }
]])

local function drawPause(ww,wh)
    local w,h = ww or love.graphics.getWidth(),wh or love.graphics.getHeight()
    paused = love.graphics.newCanvas(w,h)
    love.graphics.setCanvas(paused)
    parts.entries.game.draw()
    love.graphics.setCanvas()
    funnypauseshader:send("dimensions",{w,h})
end


return {
    load = require "game/load",
    draw = function()
        love.graphics.push()
        love.graphics.translate(cam.x*cam.zoom+math.floor(ww/2),cam.y*cam.zoom+math.floor(wh/2))
        love.graphics.scale(cam.zoom)

        
        setColor(1,1,1)
        love.graphics.setBlendMode("alpha","alphamultiply")
        love.graphics.setShader(renderShader)
        for i,cx,cy in cam.eachVisibleChunk() do
            if level.chunks[cx] and level.chunks[cx][cy] then
                local x,y = math.floor((cx+cam.cx)*level.mapSize),math.floor((cy+cam.cy)*level.mapSize)
                love.graphics.draw(level.chunks[cx][cy].mapDraw,x,y,nil,.5)
            end
        end
        love.graphics.setShader()


        local minx = -cam.x-ww/cam.zoom/2-1
        local maxx = -cam.x+ww/cam.zoom/2
        local miny = -cam.y-wh/cam.zoom/2-1
        local maxy = -cam.y+wh/cam.zoom/2
        for i,cx,cy in cam.eachVisibleChunk() do
            if level.entitiesInChunks[cx] and level.entitiesInChunks[cx][cy] then
                local tcx,tcy = math.floor((cx+cam.cx)*level.mapSize),math.floor((cy+cam.cy)*level.mapSize) -- transformed chunk x/y

                local chunk = level.chunks[cx][cy]
                local eic = level.entitiesInChunks[cx][cy]
                if not chunk.spriteBatch then
                    chunk.spriteBatch = love.graphics.newSpriteBatch(imageEntityPallete,5000,"stream")
                    for k, v in pairs(eic) do
                        local e = level.entities[k]
                        if not e.drawID then
                            e.drawID = chunk.spriteBatch:add(quadPallete[e.color or entityAtlas[e.name].color],e.x,e.y,nil,.5)
                        end
                    end
                end
                
                love.graphics.draw(chunk.spriteBatch,tcx,tcy)
            end
        end

        local max;
        for i,cx,cy in cam.eachVisibleChunk() do
            max = i
            local x,y = math.floor((cx+cam.cx)*level.mapSize),math.floor((cy+cam.cy)*level.mapSize)
            love.graphics.rectangle("line",x,y,level.mapSize,level.mapSize)
            love.graphics.print(string.format("%d %d %d",i,cx,cy),x+level.mapSize/2,y)
        end

        love.graphics.setLineWidth(1/cam.zoom)

        do
            local mcx,mcy, mtx,mty, mox,moy = cam.screenPosToTilePos()
            if level.chunks[mcx] and level.chunks[mcx][mcy] then
                love.graphics.setLineWidth(1/cam.zoom)
                love.graphics.rectangle("line",mtx+(mcx+cam.cx)*level.mapSize,mty+(mcy+cam.cy)*level.mapSize,1,1)
                love.graphics.rectangle("line",0,0,1,1)
            end
            setColor(1,0,0,.5)
            local mx,my;
            if love.keyboard.isDown("rshift") then
                mx,my = mtx+(math.floor(mox*4)/4%1)-2,mty+(math.floor(moy*4)/4%1)-2
            else
                mx,my = mtx+(mox%1)-2,mty+(moy%1)-2
            end

            setColor(1,1,1)
        end

        love.graphics.pop()

        love.graphics.print(table.concat({
            "active chunks: "..level.activeChunks,
            "fps: "..love.timer.getFPS(),
            "entities: "..#level.entities,
        },"\n"))

        local a = (MODEL or 0)+0
        for i = 0, 3 do
            if a%2 == 1 then
                love.graphics.rectangle("fill",50+20*(i%2),50+20*math.floor(i/2),20,20)
            end
            a = math.floor(a/2)
            love.graphics.rectangle("line",50,50,40,40)
        end

        for i = 1, 3 do
            clicked[i] = love.mouse.isDown(i)
        end
    end,
    update = function(dt)
        for i = 1, 3 do
            clicked[i] = love.mouse.isDown(i) and not clicked[i]
        end

        ww,wh = love.graphics.getDimensions()

        do
            local a,b = ww/2/cam.zoom, wh/2/cam.zoom
            cam.minx,cam.miny = math.floor((-a-cam.x)/level.mapSize-cam.cx), math.floor((-b-cam.y)/level.mapSize-cam.cy)
            cam.maxx,cam.maxy = math.floor((a-cam.x)/level.mapSize-cam.cx), math.floor((b-cam.y)/level.mapSize-cam.cy)
        end

        
        --[[cam.x = cam.x+((key.left and 5 or 0)+(key.right and -5 or 0))*(key.sprint and 1 or dt)
        cam.y = cam.y+((key.up and 5 or 0)+(key.down and -5 or 0))*(key.sprint and 1 or dt)]]


        local now = (love.timer.getTime()-tickStart)*tps
        while now>ticks do
            for k, v in pairs(keyBinding) do
                key[k] = love.keyboard.isDown(v) and math.min((key[k] or 0)+1,2)
            end
            --local dt = math.ceil(now)-ticks
            for i,cx,cy in cam.eachVisibleChunk() do
                if level.entitiesInChunks[cx] and level.entitiesInChunks[cx][cy] and level.chunks[cx] and level.chunks[cx][cy] then
                    local chunk = level.chunks[cx][cy]
                    local eic = level.entitiesInChunks[cx][cy]
                    
                    for k, v in pairs(eic) do
                        local entity = level.entities[k]
                        local template = entityAtlas[entity.name]
                        if template.update then
                            template.update(level.entities[k])
                        end
                    end
                end
            end
            ticks = ticks+1
        end

        --[[do
            local entity = level.entities[playerID]
            local cx,cy,_,_,_,_,x,y = cam.screenPosToTilePos(ww/2,wh/2)
            local dx,dy = x-entity.x+(cx-entity.cx)*level.mapSize,y-entity.y+(cy-entity.cy)*level.mapSize
            cam.x = cam.x+dx*.5
            cam.y = cam.y+dy*.5
        end]]
        do
            local entity = level.entities[playerID]
            cam.x,cam.y,cam.cx,cam.cy = -entity.x,-entity.y,-entity.cx,-entity.cy
        end
        cam.x,cam.y,cam.cx,cam.cy = utils.fixCoords(cam.x,cam.y,cam.cx,cam.cy)

        for i,cx,cy in cam.eachVisibleChunk() do -- load chunks
            utils.autoLoadChunk(cx,cy)
            utils.updateDrawableMap(cx,cy)
        end
        if not TEst then
            local solid = {pixel.getColor(pixel.setProperty(pixel.setProperty(pixel.setProperty(pixel.big(0,0,0,0),"color",1),"model",15),"solid",1))}
            for i = 1, 10, 1 do
                utils.placetile(i*2+2,198,0,-1,{pixel.getColor(pixel.setProperty(pixel.setProperty(pixel.setProperty(pixel.big(0,0,0,0),"color",1),"model",5+i),"solid",1))})
            end
            utils.placetile(12,190,0,-1,solid)
            utils.placetile(12,193,0,-1,solid)
            utils.placetile(13,192,0,-1,solid)
            utils.placetile(5,197,0,-1,solid)
            utils.placetile(5,196,0,-1,solid)
            utils.placetile(3,197,0,-1,solid)
            utils.placetile(3,196,0,-1,solid)
            TEst = true
        end
        if clicked[1] then
            local cx,cy,x,y = cam.screenPosToTilePos()
            utils.placetile(x,y,cx,cy,WHITETILE)
        end
        if clicked[2] then
            local cx,cy,x,y = cam.screenPosToTilePos()
            utils.placetile(x,y,cx,cy,EMPTY)
        end

        coroutine.resume(utils.stepUnloading)
    end,
    wheelmoved = function(x,y)
        if love.keyboard.isDown("lshift") then
            local h = y+0
            y = x+0
            x = h
        end
        cam.zoom = cam.zoom+x
        cam.zoom = math.max(1,cam.zoom)
        MODEL = MODEL or 15
        MODEL = math.min(15,math.max(MODEL+y,0))
        WHITETILE = {pixel.getColor(pixel.setProperty(pixel.setProperty(pixel.setProperty(pixel.big(0,0,0,0),"color",1),"model",MODEL),"solid",1))}
    end,
    keypressed = function(key)
        if key == "f2" then
        end
        if key == "escape" then
            drawPause()
            local template = {gridw=10,gridh=7,size=40,cascade={button={x=1,w=8,h=1,padding=4,text_size=2}},align="center",
                {tag="button",label="resume",y=4,clicked=function()
                    paused = nil
                end},
                {tag="button",label="save",y=5,clicked=function()
                    if love.window.showMessageBox("surely?","Do you want to overwrite world at '"..level.folder.."'?",{"No","Yes"}) == 2 then
                        saveWorld(level,level.folder)
                        love.window.showMessageBox("done!","Your world at '"..level.folder.."' was saved!")
                    end
                end},
                {tag="button",label="exit",y=6,clicked=function()
                    print("a")
                    if love.window.showMessageBox("surely?","Do want to exit?",{"No","Yes"}) == 2 then
                        clear("paused","cam","level","clicked","pixel","ColorPallete","renderShader","getBits","utils","collision","keyBinding","key","clicked","tps","ticks","tickStart","tiles","tilebyname","entityAtlas","entityColor","entities","playerID","imageEntityPallete","quadPallete") -- amaezing :)
                        parts.start("menu")
                    end
                end},
                {tag="label",label="paused",x=0.12,y=0,text_size=10,w=10,h=3,align="center"}
            }
            local processed = ui.process(template)
            while paused do
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
                            paused = nil
                            return
                        end
                    end
                    if name == "resize" then
                        drawPause(a,b)
                    end
                    if name == "mousepressed" then
                        ui.mousepressed(processed,a,b,c,d)
                    end
                end

                if tickStart then
                    ticks = math.ceil((love.timer.getTime()-tickStart)*tps)
                end

                if not paused then return end


                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())

                love.graphics.setShader(funnypauseshader)
                love.graphics.draw(paused)
                love.graphics.setShader()
                ui.draw(processed)
                love.graphics.print("(frozen)")
    
                love.graphics.present()
        
                love.timer.sleep(1/20)
            end
        end

    end,
    resize = function(ww,wh)
    end
}