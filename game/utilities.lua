local utils = {}
function utils.getTileInfo(...)
    local nr,g,b = ...
    if type(nr) == "table" then
        nr,g,b = nr[1] or nr.r,nr[2] or nr.g,nr[3] or nr.b
    end
    if nr and not (g or b) then
        return utils.getTileInfo(tilebyname[nr])
    end
    return tiles[nr][g][b]
end
function utils.fixCoords(x,y,cx,cy)
    -- this game uses broken up coordinate system to expand the playable map by however the chunks are big (saved in level.mapSize, 200 in this case)
    --(x,y):   x,y in a chunk (0 to 199)
    --(cx,cy): chunk x,y (indefinite)
    local ox,oy = math.floor(x/level.mapSize),math.floor(y/level.mapSize)
    local px,py = x%level.mapSize,y%level.mapSize
    local ncx,ncy = cx+ox,cy+oy
    return px,py,ncx,ncy
end
function utils.attributePhysics(obj)
    local p = {
        physicsX = physicsX,
        physicsY = physicsY,
        fixEntityCoords = function(self)
            self.x,self.y,self.cx,self.cy = utils.fixCoords(self.x,self.y,self.cx,self.cy)
        end,
    }
    setmetatable(obj, { __index = p })
end


function utils.generateChunk(cx,cy)
    --[[layers: 
        level.chunks[cx][cy]
            map (data/draw)
            bg map (data/draw)

            light (data/draw)
            lightMask (canvas)
            sun (canvas)

            highest (array) - holds highest placed solid tiles for each x
            file (string) - goes through deloading stages
            modified (boolean) - if isn't modified, delete the entire chunk

        entities[cx][cy]

        pixel:
            see reference.png 

        stages:
            1 - fully loaded (in range around the player)

            if signal is send to clear memory, each chunk will go one by one down this ladder:
            2 - if outside of that range, remove all canvases and "highest" from the chunk
            3 - remove all drawables 
                if isn't modified (since loading from file or generated), remove from memory comepltely
            4 - save imagedatas into temporary 
    ]]
    print("generateChunk",cx,cy)
    level.chunks[cx] = level.chunks[cx] or {}
    level.chunks[cx][cy] = {}
    level.chunks[cx][cy].redraw = {}
    level.chunks[cx][cy].spriteBatchEscapes = {}
    level.chunks[cx][cy].data = {}
    level.chunks[cx][cy].map = love.image.newImageData(level.mapSize,level.mapSize)
    level.chunks[cx][cy].mapDraw = love.graphics.newCanvas(level.mapSize*2,level.mapSize*2)
    level.chunks[cx][cy].lightDraw = love.graphics.newCanvas(level.mapSize,level.mapSize)
    level.chunks[cx][cy].sunLight = love.graphics.newCanvas(level.mapSize,1)
    level.chunks[cx][cy].sunLightQue = {}

    light.generateNewSunLight(cx,cy)
    light.update(cx,cy)
    for x = -1, 1 do
        for y = -1, 1 do
            if (level.chunks[cx+x] or {})[cy+y] and utils.isVisible(cx+x,cy+y) then
                level.chunks[cx+x][cy+y].lightUpdate = true
            end
        end
    end


    level.activeChunks = level.activeChunks+1
end

function utils.generateChunkData(cx,cy)
    level.chunks[cx][cy].entities = {}
end

function utils.loadChunkFromFile(cx,cy,path)
    level.chunks[cx] = level.chunks[cx] or {}
    level.chunks[cx][cy] = {}
    level.chunks[cx][cy].spriteBatchEscapes = {}
    level.chunks[cx][cy].redraw = {}
    level.chunks[cx][cy].map = love.image.newImageData(path)
    setColor(1,1,1)
    level.chunks[cx][cy].mapDraw = love.graphics.newCanvas(level.mapSize*2,level.mapSize*2)
    level.chunks[cx][cy].lightDraw = love.graphics.newCanvas(level.mapSize,level.mapSize)
    level.chunks[cx][cy].sunLight = love.graphics.newCanvas(level.mapSize,1)
    level.chunks[cx][cy].sunLightQue = {}
    level.chunks[cx][cy].sunLightArray = {}


    local imgmap = love.graphics.newImage(path)
    love.graphics.setCanvas(level.chunks[cx][cy].mapDraw)
    love.graphics.setBlendMode("replace","premultiplied")
    love.graphics.draw(imgmap,0,0,nil,2)
    love.graphics.setCanvas(level.chunks[cx][cy].sunLight)
    love.graphics.draw(imgmap,0,-level.mapSize)
    love.graphics.setCanvas()

    level.chunks[cx][cy].tempFile = "temp/"..cx.."_"..cy
    level.chunks[cx][cy].fromFile = true
    level.chunks[cx][cy].modified = false

    if level.chunks[cx][cy-1] and level.chunks[cx][cy-1].sunLightArray then
        local sunlightdata = level.chunks[cx][cy].sunLight:newImageData()
        local above = level.chunks[cx][cy-1].sunLightArray
        for i = 0, level.mapSize-1 do
            local r,g,b = sunlightdata:getPixel(i,0)
            b = math.min(1,above[i])
            level.chunks[cx][cy].sunLightArray[i] = r*255*255 + g*255 + b*(level.mapSize+1)
            level.chunks[cx][cy].sunLightQue[i] = {update=true}
        end
    else
        local sunlightdata = level.chunks[cx][cy].sunLight:newImageData()
        for i = 0, level.mapSize-1 do
            local r,g,b = sunlightdata:getPixel(i,0)
            level.chunks[cx][cy].sunLightArray[i] = r*255*255 + g*255 + b*(level.mapSize+1)
        end
    end


    --light.generateNewSunLight(cx,cy)
    light.update(cx,cy)

    level.activeChunks = level.activeChunks+1
end

--[[function utils.loadChunkDataFromFile(cx,cy,path)
    if not (level.chunks[cx] and level.chunks[cx][cy]) then
        error("Chunk is not loaded")
    end
    local file = binser.deserialize(love.filesystem.read(path))
    level.chunks[cx][cy].entities = file.entities
    print("loadChunkDataFromFile",cx,cy,path)
end]]

function utils.unloadChunk(cx,cy)
    do
        local path = level.chunks[cx][cy].tempFile or "temp/"..cx.."_"..cy
        if level.chunks[cx][cy].modified then
            local imgdata = love.image.newImageData(level.mapSize,level.mapSize+1)
            imgdata:paste(level.chunks[cx][cy].map)
            local sunlightdata = level.chunks[cx][cy].sunLight:newImageData()
            imgdata:paste(sunlightdata,0,level.mapSize)
            imgdata:encode("png",path)
            imgdata:release()
            sunlightdata:release()
        end
    end
    
    level.chunks[cx][cy].map:release()
    level.chunks[cx][cy].mapDraw:release()
    level.chunks[cx][cy].lightDraw:release()
    level.chunks[cx][cy].sunLight:release()
    
    level.chunks[cx][cy].sunLightArray = nil
    
    level.chunks[cx][cy] = nil
    if not table.hasContent(level.chunks[cx]) then
        level.chunks[cx] = nil
    end
    level.activeChunks = level.activeChunks-1
end

function utils.loadLevel(path)
    level = {folder="worlds/"..path.."/"}

    if not love.filesystem.getInfo(level.folder) then
        if showMessageBox(level.folder.."\ndoesn't exist",{"OK","Open save dir"}) == 2 then
            love.system.openURL(love.filesystem.getSaveDirectory())
        end
        --parts.start("menu")
        --return 1
        assert(false,"World doesn't exist")
    end

    local info = json.decode(love.filesystem.read(level.folder.."info.json"))

    level.mapSize = info.mapSize
    level.player = info.player
    level.stackLimit = info.stackLimit
    level.chunks = {}

    level.entities = binser.deserialize((love.filesystem.read(level.folder.."entities")))[1]
    level.entitiesInChunks = {}

    local entityAtlas = entityAtlas or require"game.entities"[1]
    for k, v in pairs(level.entities) do
        local a,b,cx,cy = utils.fixCoords(v.x,v.y,v.cx,v.cy)
        if not (level.entitiesInChunks[cx] or {})[cy] then
            level.entitiesInChunks[cx] = level.entitiesInChunks[cx] or {}
            level.entitiesInChunks[cx][cy] = {}
        end 
        level.entities[k].x,level.entities[k].y,level.entities[k].cx,level.entities[k].cy = a,b,cx,cy
        level.entitiesInChunks[cx][cy][k] = true
        level.entities[k].drawID = nil
        level.entities[k].noBatch = entityAtlas[v.name].noBatch
        level.entities[k].id = k
        setmetatable(level.entities[k],utils.entityMetatable)
    end
    
    renderShader:send("mapSize",level.mapSize*2)
end

function utils.chunkExists(cx,cy)
    return (level.chunks[cx] or {})[cy]
end

function utils.placetile(ix,iy,icx,icy,colorCode)
    love.graphics.setShader()
    local x,y,cx,cy = utils.fixCoords(ix,iy,icx,icy)
    local chunk = level.chunks[cx][cy]
    chunk.redraw[x.."_"..y] = {x,y,colorCode}
    chunk.map:setPixel(x,y,colorCode)
    chunk.modified = true
    collision.removeFromCatche(x,y,cx,cy)
    
    chunk.lightUpdate = true

    for i = 0,7 do
        local a = i/4*math.pi
        local nx,ny = math.cos(a)*15+x,math.sin(a)*15+y
        local _,_,ncx,ncy = utils.fixCoords(nx,ny,cx,cy)
        if (not (cx == ncx and cy == ncy)) and level.chunks[ncx] and level.chunks[ncx][ncy] then
            level.chunks[ncx][ncy].lightUpdate = true
            --print("B",ncx,ncy)
        end
    end
    
    local a = cx
    local b = 0
    if x<=light.maxLevel then
        b = -1
    elseif x>=level.mapSize-light.maxLevel then
        b = 1
    end
    for ncx = a,a+b,b +1-math.abs(b) do        
        local ncy = cy+0
        while true do
            ncy = ncy+1
            if not (utils.chunkExists(ncx,ncy) and utils.isVisible(ncx,ncy)) then
                break
            else
                level.chunks[ncx][ncy].lightUpdate = true
            end
        end
    end

    level.chunks[cx][cy].sunLightQue[x] = level.chunks[cx][cy].sunLightQue[x] or {}
    local t = level.chunks[cx][cy].sunLightQue[x]
    if pixel.getProperty(pixel.big(unpack(colorCode)),"solid") == 1 then
        t.place = math.min(t.place or math.huge,y+1)+0
    elseif y == (level.chunks[cx][cy].sunLightArray[x]%(level.mapSize+1))-1 then
        t.unplace = y+1
    end

end

function utils.updateDrawableMap(cx,cy)
    local chunk = level.chunks[cx][cy]

    if table.hasContent(chunk.redraw) then
        love.graphics.setCanvas(chunk.mapDraw)
        love.graphics.setBlendMode("replace","premultiplied")
        for k, v in pairs(chunk.redraw) do
            setColor(v[3])
            love.graphics.draw(pixel.pixel,v[1]*2,v[2]*2)
        end
        love.graphics.setCanvas()
        level.chunks[cx][cy].redraw = {}
    end


end

function utils.isVisible(cx,cy)
    return cx>=cam.minx and cx<=cam.maxx and cy>=cam.miny and cy<=cam.maxy
end

utils.stepUnloading = coroutine.create(function()
    while true do
        if level.activeChunks<250 then
            coroutine.yield()
        else
            for cx, c in pairs(level.chunks) do
                for cy, chunk in pairs(c) do
                    if level.activeChunks<101 then
                        break
                    end
                    if not utils.isVisible(cx,cy) then
                        utils.unloadChunk(cx,cy)
                    end
                    coroutine.yield()
                end
            end
        end
    end
end)

function utils.autoLoadChunk(cx,cy)
    if level.chunks[cx] and level.chunks[cx][cy] then
        return
    end
    local try_png = "temp/"..cx.."_"..cy
    for i = 1, 2 do
        if love.filesystem.getInfo(try_png) then
            print("FROM FILE",cx,cy)
            utils.loadChunkFromFile(cx,cy,try_png)
            try_png = nil
        end

        local a = level.folder..cx.."_"..cy
        try_png = try_png and a..".png"
    end

    if try_png then
        print("GENERATE",cx,cy)
        utils.generateChunk(cx,cy)
    end
end

--[[local TileCatche

local function catchTile(cx,cy,x,y,color)
    TileCatche[cx] = TileCatche[cx] or {}
    TileCatche[cx][cy] = TileCatche[cx][cy] or {}
    TileCatche[cx][cy][x] = TileCatche[cx][cy][x] or {}

    TileCatche[cx][cy][x][y] = color
end]]

function utils.getTile(x,y,cx,cy)
    if not (level.chunks[cx] and level.chunks[cx][cy]) then
        utils.autoLoadChunk(cx,cy)
    end
    return pixel.big(level.chunks[cx][cy].map:getPixel(x,y))
end
function utils.getTileRGB(x,y,cx,cy)
    if not (level.chunks[cx] or level.chunks[cx][cy]) then
        utils.autoLoadChunk(cx,cy)
    end
    return level.chunks[cx][cy].map:getPixel(x,y)
end

function utils.summonEntity(name,x,y,_cx,_cy,w,h, signal)
    local a,b,cx,cy = utils.fixCoords(x,y,_cx,_cy)
    if not (level.entitiesInChunks[cx] or {})[cy] then
        level.entitiesInChunks[cx] = level.entitiesInChunks[cx] or {}
        level.entitiesInChunks[cx][cy] = {}
    end 

    table.insert(level.entities,{
        name = name.."",
        x=a,y=b,cx=cx,cy=cy,
        w= w or entityAtlas[name].w or 1,h= h or entityAtlas[name].h or 1,
    })
    local i = #level.entities

    setmetatable(level.entities[i],utils.entityMetatable)

    local entity = level.entities[i]
    
    entity.id = i+0

    level.entitiesInChunks[cx][cy][i] = true

    if entityAtlas[name].summoned then
        entity:summoned(signal)
    end

    return i
end

function utils.deleteEntity(id)
    local entity = level.entities[id]
    level.entitiesInChunks[entity.cx][entity.cy][id] = nil
    level.chunks[entity.cx][entity.cy].spriteBatch[entity.spriteBatchType]:set(entity.drawID,0,0,0,0)
    level.chunks[entity.cx][entity.cy].spriteBatchEscapes[entity.spriteBatchType] = (level.chunks[entity.cx][entity.cy].spriteBatchEscapes[entity.spriteBatchType] or 0)+1
    level.entities[id] = nil
end

function utils.encodePosition(x,y,cx,cy)
    return (x+y*level.mapSize) .."_"..cx.."_"..cy
end

local ignoreKeys = {}

function utils.ignoreFirstInputs(keys)
    ignoreKeys = keys
end

function utils.updateKeys(keyBinding,key)
    for k, v in pairs(keyBinding) do
        local condition;
        if string.find(v,"gamepad") then
            -- placeholder
        elseif v..""~=v then
            condition = love.mouse.isDown(v)
        else
            condition = love.keyboard.isDown(v)
        end
        ignoreKeys[k] = (ignoreKeys[k] and condition) or nil
        condition = condition and not ignoreKeys[k]
        key[k] = condition and math.min((key[k] or 0)+1,2)
    end
end

function utils.atInvPos(inv,pos)
    local i = 0
    while true do
        i=i+1 
        if (not inv[i]) or inv[i].invpos>pos then
            return 0
        elseif inv[i].invpos == pos then
            break
        end
    end
    return i
end

function utils.drawTile(colorcode,x,y,w,emptyBitColor)
    local color = pixel.getProperty(colorcode,"color")
    local model = pixel.decodeModel(pixel.getProperty(colorcode,"model"))
    local mark = pixel.getProperty(colorcode,"mark") == 1
    local c = ColorPallete[color+1]
    setColor(c)
    local first = true
    for i = 0, 3 do
        setColor(c)
        if model[i+1] then
            if first and mark then
                setColor(c[1]+.25,c[2]+.25,c[3]+.25,c[4])
            end
            love.graphics.rectangle("fill",x+w*(i%2)/2,y+w*math.floor(i/2)/2,w/2,w/2)
            first = false
        elseif emptyBitColor then
            setColor(emptyBitColor)
            love.graphics.rectangle("fill",x+w*(i%2)/2,y+w*math.floor(i/2)/2,w/2,w/2)
        end
    end
end


local modelsGrouped = {
    [13]=1,[14]=1,[11]=1,[7]=1,
    [2]=2,[1]=2,[8]=2,[4]=2,
    [3]=3,[12]=3,[5]=3,[10]=3,
    [6]=4,[9]=4,
}
utils.modelsGrouped = modelsGrouped
local modelRotateGroups = {
    {14,13,7,11,offset=0},    --stairs
    {8,4,1,2,offset=0},       --bits
    {12,5,3,10,offset=-.25},  --slabs
    {6,9},                    --checker
}
function utils.rotateModelTowards(model,angle)
    if modelsGrouped[model] then
        local t = modelRotateGroups[modelsGrouped[model]]
        local l,o = #t,(t.offset or 0)*math.pi
        local d = (math.floor((angle+o)/math.pi/2*l)+l)%l+1
        return t[d]
    else
        return model
    end
end

utils.entityMetatable = {
    __index = function(table,key)
        if key == "quad" then
            return table.customQuad or quadPallete[table.color or entityAtlas[table.name].color]
        end
        return entityAtlas[table.name][key] or entityAtlas.default[key]
    end
}

utils.sortContent = function(a,b)
    return a.invpos<b.invpos
end

function utils.generateSpriteBatches(chunk)
    if not chunk.spriteBatch then
        chunk.spriteBatch = {}
    end
    if not chunk.spriteBatch.entity then
        chunk.spriteBatch.entity = love.graphics.newSpriteBatch(imageEntityPallete,5000,"stream")
    end
    if not chunk.spriteBatch.item then
        chunk.spriteBatch.item = love.graphics.newSpriteBatch(items.img,2000,"stream")
    end    
    if not chunk.spriteBatch.tileitem then
        chunk.spriteBatch.tileitem = love.graphics.newSpriteBatch(tileBatchMap,2000,"stream")
    end
end

--level.data[x.."_"..y.."_"..cx.."_"..cy]

function math.replacenan(x,y) return (tonumber(x) and x==x) and x or y end
function math.angledist(x,y) return (y-x +math.pi) %(math.pi*2) -math.pi end
function xor(x,y) return (not x and y) or (x and not y) end
function string.split(s,d)
    if d == nil then
        d = "%s"
    end
    local t = {}
    for v in string.gmatch(s, "([^"..d.."]+)") do
        table.insert(t,v)
    end
    return t
end



return utils