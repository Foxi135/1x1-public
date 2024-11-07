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
    end
}


local entities = {
    test = {color=1},
    test2 = {color=2,
        summoned = function(entity,justLoad)
            
        end,
        update = function(entity,dt)
            if entity.id == 2 then
                local a,b,c,d = cam.screenPosToTilePos()
                manipulate.move(entity,c,d,a,b)
            end
        end
    }
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