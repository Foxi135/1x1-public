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
    level.chunks[cx] = level.chunks[cx] or {}
    level.chunks[cx][cy] = {}
    level.chunks[cx][cy].redraw = {}
    level.chunks[cx][cy].map = love.image.newImageData(level.mapSize,level.mapSize)
    level.chunks[cx][cy].mapDraw = love.graphics.newCanvas(level.mapSize*2,level.mapSize*2)

    level.activeChunks = level.activeChunks+1
end

function utils.generateChunkData(cx,cy)
    level.chunks[cx][cy].entities = {}
end

function utils.loadChunkFromFile(cx,cy,path)
    level.chunks[cx] = level.chunks[cx] or {}
    level.chunks[cx][cy] = {}
    level.chunks[cx][cy].redraw = {}
    level.chunks[cx][cy].map = love.image.newImageData(path)

    level.chunks[cx][cy].mapDraw = love.graphics.newCanvas(level.mapSize*2,level.mapSize*2)
    love.graphics.setCanvas(level.chunks[cx][cy].mapDraw)
    love.graphics.setBlendMode("replace","premultiplied")
    love.graphics.draw(love.graphics.newImage(path),0,0,nil,2)
    love.graphics.setCanvas()

    level.chunks[cx][cy].tempFile = "temp/"..cx.."_"..cy
    level.chunks[cx][cy].fromFile = true
    level.chunks[cx][cy].modified = false

    level.activeChunks = level.activeChunks+1
end

function utils.loadChunkDataFromFile(cx,cy,path)
    if not (level.chunks[cx] and level.chunks[cx][cy]) then
        error("Chunk is not loaded")
    end
    local file = binser.deserialize(love.filesystem.read(path))
    level.chunks[cx][cy].entities = file.entities
    print(inspect(file))
end

function utils.unloadChunk(cx,cy)
    do
        local path = level.chunks[cx][cy].tempFile or "temp/"..cx.."_"..cy
        if level.chunks[cx][cy].modified then
            level.chunks[cx][cy].map:encode("png",path)
        end
        local includeEntities-- = table.hasContent(level.chunks[cx][cy].entities)
        if includeEntities then
            love.filesystem.write(path..".bin",binser.serialize({
                entities = level.chunks[cx][cy].entities
            }))
        end
    end
    
    level.chunks[cx][cy].map:release()
    level.chunks[cx][cy].mapDraw:release()
    level.chunks[cx][cy] = nil
    if not table.hasContent(level.chunks[cx]) then
        level.chunks[cx] = nil
    end
    level.activeChunks = level.activeChunks-1
end

function utils.loadLevel(path)
    level = {folder="worlds/"..path.."/"}
    local info = json.decode(love.filesystem.read(level.folder.."info.json"))

    level.mapSize = info.mapSize
    level.player = info.player
    level.stackLimit = info.stackLimit
    level.chunks = {}
    
    renderShader:send("mapSize",level.mapSize*2)
end


function utils.placetile(ix,iy,icx,icy,colorCode)
    love.graphics.setShader()
    local x,y,cx,cy = utils.fixCoords(ix,iy,icx,icy)
    local chunk = level.chunks[cx][cy]
    chunk.redraw[x.."_"..y] = {x,y,colorCode}
    chunk.map:setPixel(x,y,colorCode)
    chunk.modified = true
end

function utils.updateDrawableMap(cx,cy)
    local chunk = level.chunks[cx][cy]
    if not table.hasContent(chunk.redraw) then
        return
    end
    love.graphics.setCanvas(chunk.mapDraw)
    love.graphics.setBlendMode("replace","premultiplied")
    for k, v in pairs(chunk.redraw) do
        setColor(v[3])
        love.graphics.draw(pixel.pixel,v[1]*2,v[2]*2)
    end
    love.graphics.setCanvas()
    level.chunks[cx][cy].redraw = {}
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

function utils.summonEntity(name,x,y,cx,cy, signal)
    if not (level.entitiesInChunks[cx] or {})[cy] then
        level.entitiesInChunks[cx] = level.entitiesInChunks[cx] or {}
        level.entitiesInChunks[cx][cy] = {}
    end 
    local a,b,c,d = utils.fixCoords(x,y,cx,cy)

    table.insert(level.entities,{
        name = name.."",
        x=a,y=b,cx=c,cy=d,
    })
    local i = #level.entities

    local entity = level.entities[i]
    
    entity.id = i+0

    level.entitiesInChunks[cx][cy][i] = true
    
    if entityAtlas[name].summoned then
        entityAtlas[name].summoned(entity,signal)
    end

    return i
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

function utils.drawTile(colorcode,x,y,w)
    local color = pixel.getProperty(colorcode,"color")
    local model = pixel.decodeModel(pixel.getProperty(colorcode,"model"))
    setColor(ColorPallete[color+1])
    for i = 0, 3 do
        if model[i+1] then
            love.graphics.rectangle("fill",x+w*(i%2)/2,y+w*math.floor(i/2)/2,w/2,w/2)
        end
    end
end

function math.replacenan(x,y) return (tonumber(x) and x==x) and x or y end
function math.angledist(x,y) return (y-x +math.pi) %(math.pi*2) -math.pi end
function xor(x,y) return (not x and y) or (x and not y) end



return utils