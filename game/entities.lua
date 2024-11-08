local function unpackPosition(entity,...)
    return entity.x,entity.y,entity.cx,entity.cy,...
end

local floor,hfloor,ceil = math.floor,math.halfFloor,math.ceil
local manipulate = {
    move = function(entity,x,y,cx,cy)
        local prevcx,prevcy = entity.cx+0,entity.cy+0
        entity.x,entity.y,entity.cx,entity.cy = x+0,y+0,cx+0,cy+0
        local chunk = level.chunks[cx][cy]
        if prevcx ~= cx or prevcy ~= cy then
            level.entitiesInChunks[prevcx][prevcy][entity.id] = nil
            level.entitiesInChunks[cx] = level.entitiesInChunks[cx] or {}
            level.entitiesInChunks[cx][cy] = level.entitiesInChunks[cx][cy] or {}
            level.entitiesInChunks[cx][cy][entity.id] = true
            if entity.drawID and level.entitiesInChunks[prevcx] and level.entitiesInChunks[prevcx][prevcy] then
                level.chunks[prevcx][prevcy].spriteBatch:set(entity.drawID,0,0,0,0)
                entity.drawID = nil
            end
        end
        if chunk.spriteBatch then
            if entity.drawID then
                chunk.spriteBatch:set(entity.drawID,quadPallete[entityAtlas[entity.name].color],entity.x,entity.y,nil,.5)
            else
                entity.drawID = chunk.spriteBatch:add(quadPallete[entityAtlas[entity.name].color],entity.x,entity.y,nil,.5)
            end
        end
    end,
    updatePos = function(entity,prevcx,prevcy) -- gl reading this lmao
        entity.x,entity.y,entity.cx,entity.cy = utils.fixCoords(unpackPosition(entity))
        local cx,cy = entity.cx,entity.cy
        local chunk = level.chunks[cx][cy]
        if prevcx ~= cx or prevcy ~= cy then
            level.entitiesInChunks[prevcx][prevcy][entity.id] = nil
            level.entitiesInChunks[cx] = level.entitiesInChunks[cx] or {}
            level.entitiesInChunks[cx][cy] = level.entitiesInChunks[cx][cy] or {}
            level.entitiesInChunks[cx][cy][entity.id] = true
            if entity.drawID and level.entitiesInChunks[prevcx] and level.entitiesInChunks[prevcx][prevcy] then
                level.chunks[prevcx][prevcy].spriteBatch:set(entity.drawID,0,0,0,0)
                entity.drawID = nil
            end
        end
        if chunk.spriteBatch then
            if entity.drawID then
                chunk.spriteBatch:set(entity.drawID,quadPallete[entityAtlas[entity.name].color],entity.x,entity.y,nil,.5)
            else
                entity.drawID = chunk.spriteBatch:add(quadPallete[entityAtlas[entity.name].color],entity.x,entity.y,nil,.5)
            end
        end
    end,
    physicsY = function(entity)
        entity.vy = entity.vy+entity.accy
        entity.y = entity.y+entity.vy
        if (collision.isColliding(unpackPosition(entity,1,1,true))) then
            local d = entity.vy/math.abs(entity.vy)/2
            entity.y = hfloor(entity.y)
            while collision.isColliding(unpackPosition(entity,1,1,true)) do
                entity.y = entity.y-d
            end
            entity.vy = 0
        end
    end,

}




local entities = {
    test = {color=1},
    test2 = {color=2,
        summoned = function(entity,justLoad)
            entity.vx,entity.vy = 0,0
            entity.accx,entity.accy = 0.05,0.05
        end,
        update = function(entity,dt)
            local a,b = entity.cx+0,entity.cy+0
            manipulate.physicsY(entity)

            manipulate.updatePos(entity,a,b)
        end
    },
}


local colorPallete = {
    {{0,1,0,1},{1,0,0,1}},
    {{0,1,1,1},{1,0,1,1}},
}


local quadPallete = {}
local pallete = love.image.newImageData(#colorPallete*4,2)
for k, v in pairs(colorPallete) do
    if type(v[1]) == "table" then
        pallete:setPixel(k*4-3  ,0,v[1])
        pallete:setPixel(k*4-3  ,1,v[2])
        pallete:setPixel(k*4-2 ,1,v[1])
        pallete:setPixel(k*4-2 ,0,v[2])
    else
        pallete:setPixel(k*4-3  ,0,v)
        pallete:setPixel(k*4-3  ,1,v)
        pallete:setPixel(k*4-2 ,1,v)
        pallete:setPixel(k*4-2 ,0,v)
    end
    table.insert(quadPallete,love.graphics.newQuad(k*4-3,0,2,2,pallete:getDimensions()))
end

return {entities,love.graphics.newImage(pallete),quadPallete}