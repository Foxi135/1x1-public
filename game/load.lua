return function(last,arg)
    function table.hasContent(table)
        local a,b = pairs(table or {})
        return a(b) or false
    end
    
    function math.halfFloor(x)
        return x-x%.5
    end
    function math.halfCeil(x)
        return x-x%.5+.5
    end
    

    
    function getBits(number,start,len)
        return math.floor(number/(2^start)) % (2^len)
    end
    
    pixel = {properties = {id={21,10},color={8,6},solid={16,1},opaque={18,1},mark={17,1},model={4,4},light={0,4}}}
    function pixel.getProperty(big,name)
        local a = pixel.properties[name]
        return getBits(big,a[1],a[2])
    end
    function pixel.setProperty(big,name,value)
        local a = pixel.properties[name]
        local b = big-getBits(big,a[1],a[2])*(2^a[1])
        return b+value*(2^a[1])
    end



    function pixel.big(r,g,b,a)
        return math.max(128,a*255)*16777216+
                            r*255 *65536+
                            g*255 *256+
                            b*255
    end
    function pixel.getColor(big)
        return 
            getBits(big,16,8)/255,
            getBits(big,8, 8)/255,
            getBits(big,0, 8)/255,
            getBits(big,24,8)/255
    end
    function pixel.getColor255(big)
        return 
            getBits(big,16,8),
            getBits(big,8, 8),
            getBits(big,0, 8),
            getBits(big,24,8)
    end
    function pixel.encodeModel(t)
        local n = 0
        for i, v in pairs(t) do
            n = n+(v and (2^(i-1)) or 0)
        end
        return n
    end
    function pixel.decodeModel(model)
        local t = {}
        local n = model+0
        while n>0 do
            local d = n %2
            table.insert(t,d==1)
            n = math.floor(n/2)
        end
        return t
    end
    function pixel.defineTile(tile)
        local n = pixel.big(0,0,0,0)
        for k, v in pairs(tile) do
            if v then
                n = pixel.setProperty(n,k,v)
            end
        end
        return n
    end
    function pixel.setProperties(big,...)
        local b = big+0
        local t = {...}
        for i = 1, #t, 2 do
            b = pixel.setProperty(b,t[i],t[i+1])
        end
    end
    pixel.pixel = love.image.newImageData(2,2)
    pixel.pixel:mapPixel(function()
        return 1,1,1,1
    end)
    pixel.pixel = love.graphics.newImage(pixel.pixel)
    pixel.bit = love.image.newImageData(1,1)
    pixel.bit:mapPixel(function()
        return 1,1,1,1
    end)
    pixel.bit = love.graphics.newImage(pixel.bit)
    
    pixel.entity1 = love.image.newImageData(2,2)
    pixel.entity1:setPixel(0,0,1,1,1)
    pixel.entity1:setPixel(1,1,1,1,1)
    pixel.entity1 = love.graphics.newImage(pixel.entity1)
    
    pixel.entity2 = love.image.newImageData(2,2)
    pixel.entity2:setPixel(0,1,1,1,1)
    pixel.entity2:setPixel(1,0,1,1,1)
    pixel.entity2 = love.graphics.newImage(pixel.entity2)
    
    
    utils = require "game/utilities"
    require "game/chunks"
    collision = require "game/collision"
    popup = require "game/popups"
    light = require "game/light"

    tiles,tilebyname = nil,nil
    do
        print("REQUIRING TILES")
        local t = require "game/tiles"
        tiles = t[1]
        tilebyname = t[2]
        t[3]()
    end
    items = require "game/items"
    
    entityAtlas,entityColor = unpack(require "game/entities")
    entities = entities or {}



    local status,err = pcall(utils.loadLevel,arg)
    if not status then
        print(err)
        love.graphics.clear(0,0,0)
        if showMessageBox("Something went wrong while loading this world:\n\""..arg..'"',{"Close",love.graphics.print(err) or "Copy error and close"}) == 2 then
            love.system.setClipboardText(err)
        end
        parts.start("menu")
        return
    end
    
    do
        if love.filesystem.getInfo("temp") then
            for _, v in ipairs(love.filesystem.getDirectoryItems("temp")) do
                love.filesystem.remove("temp/"..v)
            end
        else
            love.filesystem.createDirectory("temp")
        end
    end
    
    cam = {x=0,y=0,cx=0,cy=0,zoom=20,visibleChunks={}}
    do
        local function cam_visibleChunkIter(_,i)
            local x,y = i%(cam.maxx-cam.minx+1)+cam.minx,math.floor(i/(cam.maxx-cam.minx+1))+cam.miny
            if y>cam.maxy then return end
            i=i+1
            
            return i,x,y
        end
        function cam.eachVisibleChunk()
            return cam_visibleChunkIter, nil, 0
        end
    
        function cam.screenPosToTilePos(mx,my)
            local mx,my = mx or love.mouse.getX(),my or love.mouse.getY()
            local mox,moy = ((mx-ww/2)/cam.zoom-cam.x), ((my-wh/2)/cam.zoom-cam.y)
            local mcx,mcy = math.floor(mox/level.mapSize-cam.cx), math.floor(moy/level.mapSize-cam.cy)
            local mutx,muty = mox%level.mapSize,moy%level.mapSize
            local mtx,mty = math.floor(mutx),math.floor(muty)
            return mcx,mcy,mtx,mty,mox,moy,mutx,muty
        end

    end
    
    
    keyBinding = data.keyBinding
    key = {}
    clicked = {}
    
    tps = 30
    ticks = 0
    tickStart = love.timer.getTime()
    

    
    level.activeChunks = 0

    
    for i = 1, 3 do
        clicked[i] = true
    end
    

    
    playerID = utils.summonEntity("player",level.player.x,level.player.y,level.player.cx,level.player.cy)
    level.entities[playerID].color = entityColor.addColor(level.player.color)
    level.entities[playerID].content = level.player.inventory
    level.entities[playerID].inHand = level.player.inHand+0
    imageEntityPallete,quadPallete = entityColor.refresh()
    do
        local entity = level.entities[playerID]
        cam.x,cam.y,cam.cx,cam.cy = -entity.x,-entity.y,-entity.cx,-entity.cy
    end

    local a = {}
    utils.updateKeys(data.keyBinding,a)
    utils.ignoreFirstInputs(a)

    popup.entries.inventory.creative = popup.entries.inventory.initcreative{
        {id=2,color=2,solid=1,tilemodel={true,true,true,true}},
        {id=1,color=1,solid=1,opaque=1,tilemodel={true,true,true,true}},
        {id=1,color=1,solid=1,tilemodel={false,true,true,false}},
        {id=1,color=1,solid=1,tilemodel={true,false,false,true}},

        {id=1,color=1,solid=1,tilemodel={false,true,true,true}},
        {id=1,color=1,solid=1,tilemodel={true,false,true,true}},
        {id=1,color=1,solid=1,tilemodel={true,true,false,true}},
        {id=1,color=1,solid=1,tilemodel={true,true,true,false}},

        {id=1,color=1,solid=1,tilemodel={true,true,false,false}},
        {id=1,color=1,solid=1,tilemodel={false,false,true,true}},
        {id=1,color=1,solid=1,tilemodel={true,false,true,false}},
        {id=1,color=1,solid=1,tilemodel={false,true,false,true}},
        
        {id=1,color=1,solid=1,tilemodel={true,false,false,false}},
        {id=1,color=1,solid=1,tilemodel={false,true,false,false}},
        {id=1,color=1,solid=1,tilemodel={false,false,true,false}},
        {id=1,color=1,solid=1,tilemodel={false,false,false,true}},
        

        {id=1},{id=2},{id=3},{id=4},
        {id=5},
        {id=6},

        {id=3,color=6,light=15,tilemodel={true,true,true,true}},
    }

    parts.entries.game.resize(love.graphics.getDimensions())

    stats = {
        updatedEntities = 0
    }

    light.createProcessCanvases()
end

