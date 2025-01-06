
love.keyboard.setKeyRepeat(true)

function saveWorld(level,folder)
    local player = level.entities[playerID]
    local info = {
        mapSize = level.mapSize,
        stackLimit = level.stackLimit,
        player = {
            x=player.x,y=player.y,cx=player.cx,cy=player.cy,
            color = level.player.color, --entityColor.getColor(level.entities[playerID].color)
            inventory = player.content,
            inHand = player.inHand,
        },
    }
    local entities = {}
    for k, v in pairs(level.entities) do
        if type(v)=="table" and k ~= playerID and v.permanent then
            table.insert(entities,v)
        end
    end

    for k, v in pairs(entities) do
        v.id = nil
        v.drawID = nil
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
            return vec4(0,0,0,1);
        }
        return p*vec4(0.5,0.5,0.5,1);
    }
]])
local funnyitemshader = stripesShader
local cover;
local function updatecover(ww,wh)
    local w,h = ww or love.graphics.getWidth(),wh or love.graphics.getHeight()
    cover = love.graphics.newCanvas(w,h)
    funnypauseshader:send("dimensions",{w,h})
end


local function drawPause(ww,wh)
    local w,h = ww or love.graphics.getWidth(),wh or love.graphics.getHeight()
    paused = love.graphics.newCanvas(w,h)
    love.graphics.setCanvas(paused)
    parts.entries.game.draw()
    love.graphics.draw(cover)
    setColor(0,0,0,.5)
    love.graphics.rectangle("fill",0,0,w,h)
    love.graphics.setCanvas()
    funnypauseshader:send("dimensions",{w,h})
end

function SETUP()
    UNFOLLOWCAM = true
    SLOW = 5
    ticks = (love.timer.getTime()-tickStart)*(SLOW or tps)
end


return {
    load = require "game/load",
    draw = function()
        --love.graphics.setBackgroundColor(.5,.5,1,1)

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
                    chunk.spriteBatch = {
                        entity = love.graphics.newSpriteBatch(imageEntityPallete,5000,"stream"),
                        item = love.graphics.newSpriteBatch(items.img,5000,"stream"),
                    }
                    for k, v in pairs(eic) do
                        local e = level.entities[k]
                        local sw = e.customQuadScaleW or .5
                        local sh = e.customQuadScaleH or .5
                        if not (e.drawID or e.noBatch) then
                            e.drawID = chunk.spriteBatch[e.spriteBatchType or "entity"]:add(e.customQuad or quadPallete[e.color or entityAtlas[e.name].color],e.x,e.y,nil,sw *e.w,sh *e.h)
                        end
                    end
                end

                
                love.graphics.draw(chunk.spriteBatch.entity,tcx,tcy)
                love.graphics.draw(chunk.spriteBatch.item,tcx,tcy)
            end
        end

        for k, v in pairs(cam.entitiesToDraw) do
            local e = level.entities[v]
            entityAtlas[e.name].draw(e,e.x+(e.cx+cam.cx)*level.mapSize,e.y+(e.cy+cam.cy)*level.mapSize)
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
            local player = level.entities[playerID]
            local item = utils.atInvPos(player.content,player.inHand)
            item = item and player.content[item]

            local mcx,mcy, mtx,mty, mox,moy = cam.screenPosToTilePos()
            if level.chunks[mcx] and level.chunks[mcx][mcy] then
                local x,y = mtx+(mcx+cam.cx)*level.mapSize,mty+(mcy+cam.cy)*level.mapSize
                if item and item.type == "tile" then
                    local t = utils.getTile(mtx,mty,mcx,mcy)
                    local maching_color = pixel.getProperty(item.code,"color")==pixel.getProperty(t,"color")
                    
                    love.graphics.setShader(funnyitemshader)
                    local a,b,c = love.graphics.getBackgroundColor()
                    utils.drawTile(item.code,x,y,1,maching_color and {a,b,c,180/255})
                    love.graphics.setShader()
                end
                setColor(1,1,1)
                love.graphics.rectangle("line",x,y,1,1)
            end
            setColor(1,0,0,.5)
            local mx,my;
            if love.keyboard.isDown("rshift") then
                mx,my = mtx+(math.floor(mox*4)/4%1)-2,mty+(math.floor(moy*4)/4%1)-2
            else
                mx,my = mtx+(mox%1)-2,mty+(moy%1)-2
            end
            
            setColor(1,1,1)
            if item and item.type == "item" then
                local x,y,cx,cy = player.x+.5,player.y+.5,player.cx,player.cy
                mtx,mty = mtx+mox%1-(cx-mcx)*level.mapSize,mty+moy%1-(cy-mcy)*level.mapSize

                local angle = -math.atan2(y-mty,mtx-x)
                cam.handAngle = angle+0
                local d = (angle-math.pi*3.5)%(-math.pi*2)+math.pi
                d = d/math.abs(d)
                local a = math.pi/4 --(180/4)
                local s = 6
                local l = data.handLen*2

                if player.usingItemAnim then
                    local t = data.swingLen+0
                    local b = math.pi*2 *data.swingAngle*d         -- 360 *swingAngle*d (-1 or 1)
                    angle = angle+b/2-b*(love.timer.getTime()%t)/t --       (0 to 1)     
                    player.usingItemAnim = false
                end
                
                if not items[item.id].maxdur then
                    d = -d
                    l = l/2
                end

                local fx,fy = x+(cx+cam.cx)*level.mapSize,y+(cy+cam.cy)*level.mapSize
                fx,fy = fx+math.cos(angle)*l,fy+math.sin(angle)*l
                
                setColor(1,1,1)
                love.graphics.draw(items.img,items[item.id].quad,fx,fy,angle+a*d,1/s,d/s,0,8)
            end
        end

        love.graphics.pop()

        local slotSize = 40
        local slotPadding = 4
        local w = slotSize-slotPadding*2
        love.graphics.push()
        love.graphics.translate(ww/2-slotSize*2,wh-slotSize-1)

        local slotitems = {}
        for k, item in pairs(level.entities[playerID].content) do
            if item then
                if item.invpos>4 then
                    break
                else
                    slotitems[item.invpos] = item
                    if #item>=4 then
                        break
                    end
                end
            end
        end

        local inHand = level.entities[playerID].inHand+0

        for i = 1, 4 do
            local x = (i-1)*slotSize
            setColor(0,0,0,.9)
            love.graphics.rectangle("fill",x,0,slotSize,slotSize)
            local item = slotitems[i]

            if item and item.type=="tile" then
                utils.drawTile(item.code,x+slotPadding,slotPadding,w)
            elseif item and item.type=="item" then
                setColor(1,1,1)
                love.graphics.draw(items.img,items[item.id].quad,x+slotPadding,slotPadding,nil,w/8)
                if item.durability then
                    --love.graphics.rectangle("fill",)
                end
            end
            if item and item.amount~=1 then
                local tp = 2
                setColor(0,0,0,.75)
                love.graphics.rectangle("fill",x+slotPadding,slotPadding,font:getWidth(item.amount or "nil")+tp*2-1,fh-2)
                setColor(1,1,1)
                love.graphics.print(item.amount or "nil",x+slotPadding+tp,slotPadding)

            end
        end
        setColor(1,1,1)
        love.graphics.rectangle("line",(inHand-1)*slotSize,0,slotSize,slotSize)

        love.graphics.pop()
        
        if popup.active then
            love.graphics.setShader(funnypauseshader)
            setColor(0,0,0,0)
            love.graphics.draw(cover)
            love.graphics.setShader()
            popup.draw()
        end


        love.graphics.print(table.concat({
            "active chunks: "..level.activeChunks,
            "fps: "..love.timer.getFPS(),
            "entities: "..#level.entities,
            "updating entities: "..UPDATEDENTITIESCOUNT,
            "isColliding calls per tick: "..(PROTOTYPE or 0),
        },"\n"))

    end,
    update = function(dt)
        ww,wh = love.graphics.getDimensions()

        if key.rotate then
            local ww,wh = love.graphics.getDimensions()
            local mx,my = love.mouse.getPosition()
            local x,y = ((mx-ww/2)/cam.zoom-cam.x)%1, ((my-wh/2)/cam.zoom-cam.y)%1
            local tileDirection = math.atan2(y-.5, x-.5)

            do
                local player = level.entities[playerID]
                local item = utils.atInvPos(player.content,player.inHand)
                item = player.content[item]
                if item and item.type == "tile" then
                    item.code = pixel.setProperty(item.code,"model",utils.rotateModelTowards(pixel.getProperty(item.code,"model"),tileDirection))
                end
            end
        end

        do
            local a,b = ww/2/cam.zoom, wh/2/cam.zoom
            cam.mintx,cam.minty = -a-cam.x,-b-cam.y
            cam.maxtx,cam.maxty =  a-cam.x, b-cam.y

            cam.minx,cam.miny = math.floor(cam.mintx/level.mapSize-cam.cx), math.floor(cam.minty/level.mapSize-cam.cy)
            cam.maxx,cam.maxy = math.floor(cam.maxtx/level.mapSize-cam.cx), math.floor(cam.maxty/level.mapSize-cam.cy)

            cam.mintx,cam.minty = cam.mintx%level.mapSize,cam.minty%level.mapSize
            cam.mintx,cam.minty = cam.mintx%level.mapSize,cam.minty%level.mapSize
        end

        local now = (love.timer.getTime()-tickStart)*(SLOW or tps)

        while now>ticks do
            if popup.active then 
                key={}
                popup.key = popup.key or {}
                utils.updateKeys(keyBinding,popup.key)
            else
                utils.updateKeys(keyBinding,key)
            end
            if key.inventory then
                local playerinv = level.entities[playerID].content
                popup.evoke("inventory",{
                    playerinv,
                    popup.entries.inventory.creative
                })
            end

            --local dt = math.ceil(now)-ticks

            UPDATEDENTITIESCOUNT = 0

            --collision.resetCatche()
            cam.entitiesToDraw = {}
            for i,cx,cy in cam.eachVisibleChunk() do
                if level.entitiesInChunks[cx] and level.entitiesInChunks[cx][cy] and level.chunks[cx] and level.chunks[cx][cy] then
                    local chunk = level.chunks[cx][cy]
                    local eic = level.entitiesInChunks[cx][cy]
                    
                    for k, v in pairs(eic) do
                        local entity = level.entities[k]
                        local template = entityAtlas[entity.name]
                        if template.draw then
                            table.insert(cam.entitiesToDraw,k)
                        end
                        if template.update then
                            template.update(level.entities[k])
                        end
                        UPDATEDENTITIESCOUNT = UPDATEDENTITIESCOUNT+1
                    end

                end
            end

            ticks = ticks+1
        end
        if key.place or key.unplace then
            local cx,cy,x,y = cam.screenPosToTilePos()
            local player = level.entities[playerID]
            local item = player.content[utils.atInvPos(player.content,player.inHand)]
            
            if not item or item.type == "tile" then
                placed = placed or {}
                local poscode = utils.encodePosition(x,y,cx,cy)
                if not placed[poscode] then
                    if key.unplace then
                        utils.placetile(x,y,cx,cy,{0,0,0,0})
                    elseif item then
                        utils.placetile(x,y,cx,cy,{pixel.getColor(item.code)})
                    end
                    placed[poscode] = true
                end
            elseif item.type == "item" then
                if (key.unplace and not placed) or key.place then
                    placed = true
                    if items[item.id].used then
                        items[item.id].used(item,{x,y,cx,cy},key.place,key.unplace)
                    end
                end
            end
            player.usingItemAnim = true
        else
            placed = nil
        end

        if key.throw then
            local player = level.entities[playerID]
            local item = player.content[utils.atInvPos(player.content,player.inHand)]

            local angle = (cam.handAngle or 0)+0
            local player = level.entities[playerID]
            local entityID = utils.summonEntity("thrownItem",player.x+0,player.y+0,player.cx+0,player.cy+0,nil,nil,item)
            local entity = level.entities[entityID]
            entity.vx,entity.vy = math.cos(angle)*2,math.sin(angle)
        end
        
        if not UNFOLLOWCAM then
            local entity = level.entities[playerID]
            cam.x,cam.y,cam.cx,cam.cy = -entity.x,-entity.y,-entity.cx,-entity.cy
        end
        cam.x,cam.y,cam.cx,cam.cy = utils.fixCoords(cam.x,cam.y,cam.cx,cam.cy)
        
        for i,cx,cy in cam.eachVisibleChunk() do -- load chunks
            utils.autoLoadChunk(cx,cy)
            utils.updateDrawableMap(cx,cy)
        end
        
        coroutine.resume(utils.stepUnloading)
    end,
    wheelmoved = function(x,y)
        if popup.active then return end

        if love.keyboard.isDown("lshift") then
            local h = y+0
            y = x+0
            x = h
        end
        cam.zoom = cam.zoom+x
        cam.zoom = math.max(1,cam.zoom)

        level.entities[playerID].inHand = (level.entities[playerID].inHand-1-y)%4+1
    end,
    keypressed = function(key)
        
        if key == "f2" then
        end
        if key == "escape" then
            if popup.active then
                popup.close()
                return
            end
            drawPause()
            local template = {gridw=10,gridh=7,size=40,cascade={button={x=1,w=8,h=1,padding=4,text_size=2}},align="center",
                {tag="button",label="resume",y=4,clicked=function()
                    paused = nil
                end},
                {tag="button",label="save",y=5,clicked=function()
                    if showMessageBox("Do you want to overwrite world at '"..level.folder.."'?",{"No","Yes"}) == 2 then

                        do                        
                            love.graphics.setShader(funnyitemshader)
                            setColor(0,0,0)
                            love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
                            love.graphics.setShader()
                            setColor(0,0,0,0.5)
                            love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
                            setColor(1,1,1)
                            local fh = fh*3
                            for i = 0, math.ceil(love.graphics.getHeight()/fh) do
                                love.graphics.print("saving...",0,fh*i,nil,3)
                                setColor(1,1,1,0.5)
                            end
                            love.graphics.present()
                        end


                        saveWorld(level,level.folder)

                        
                        love.graphics.clear(0,0,0,0)
                        showMessageBox("Your world at '"..level.folder.."' was saved!",{"OK"})
                    end
                end},
                {tag="button",label="exit",y=6,clicked=function()
                    if showMessageBox("Do want to exit?",{"No","Yes"}) == 2 then
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
                        updatecover()
                        drawPause(a,b)
                    end
                    if name == "mousepressed" then
                        ui.mousepressed(processed,a,b,c,d)
                    end
                end

                if tickStart then
                    ticks = math.ceil((love.timer.getTime()-tickStart)*tps)
                end

                if not paused then break end


                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())
                
                setColor(1,1,1)
                love.graphics.draw(paused)
                love.graphics.setShader(funnyitemshader)
                setColor(0,0,0,180/255)
                love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
                love.graphics.setShader()
                
                ui.draw(processed)
                love.graphics.print("(frozen)")
    
                love.graphics.present()
        
                love.timer.sleep(1/20)
            end
            while (parts.loaded == "game") and (love.event.pump() or love.mouse.isDown(1)) do end
        end

    end,
    resize = function(ww,wh)
        updatecover(ww,wh)
        if data.AutoUiScale then
            data.uiScale = math.max(1,math.floor(math.min(ww,wh)/(10*40)))
        end
    end,
    event = function(...) if popup.active then popup.event(...) end end
}