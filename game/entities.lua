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
        if chunk.spriteBatch and not entity.noBatch then
            if entity.drawID then
                chunk.spriteBatch:set(entity.drawID,quadPallete[entityAtlas[entity.name].color],entity.x,entity.y,nil,.5*entity.w,.5*entity.h)
            else
                entity.drawID = chunk.spriteBatch:add(quadPallete[entityAtlas[entity.name].color],entity.x,entity.y,nil,.5*entity.w,.5*entity.h)
            end
        end
    end,
    updatePos = function(entity,prevcx,prevcy) -- gl reading this lmao
        if not entity.moved then
            return
        end
        entity.moved = false
        entity.x,entity.y,entity.cx,entity.cy = utils.fixCoords(unpackPosition(entity))
        local cx,cy = entity.cx,entity.cy
        local chunk = (level.chunks[cx] or {})[cy]
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
        if chunk.spriteBatch and not entity.noBatch then
            local sw = entity.customQuadScaleW or .5
            local sh = entity.customQuadScaleH or .5
            if entity.drawID then
                chunk.spriteBatch:set(entity.drawID,entity.customQuad or quadPallete[entity.color or entityAtlas[entity.name].color],entity.x,entity.y,nil,sw*entity.w,sh*entity.h)
            else
                entity.drawID = chunk.spriteBatch:add(entity.customQuad or quadPallete[entity.color or entityAtlas[entity.name].color],entity.x,entity.y,nil,sw*entity.w,sh*entity.h)
            end
        end
    end,
    physicsY = function(entity,skipevents)
        if entity.vy == 0 then 
            entity.vy = entity.vy+entity.gravity
            return 
        end

        local h = entity.y+0
        entity.y = entity.y+entity.vy
        
        local a = hfloor(math.abs(entity.vy))
        local b = entity.vy>0 and 1 or 0

        if collision.isColliding(entity.x,entity.y-a*b,entity.cx,entity.cy,entity.w,entity.h+a,true) then
            local d = entity.vy/math.abs(entity.vy)/2
            if d~=d then d=.5 end 

            while not collision.isColliding(unpackPosition(entity,entity.w,entity.h,true)) do
                entity.y = entity.y-d
            end
            entity.y = hfloor(entity.y)

            while collision.isColliding(unpackPosition(entity,entity.w,entity.h,true)) do
                entity.y = entity.y-d
            end
            entity.canJump = entity.vy>=0 and love.timer.getTime() or -1
            entity.vy = 0

            entity.vx = entity.vx*(1-entity.friction)
        end
        entity.vy = entity.vy+entity.gravity
        if h~=entity.y then
            entity.moved = true
        end
        return returnevents
    end,
    physicsX = function(entity,skipevents)
        if entity.vx == 0 then return end
        local h = entity.x+0
        entity.x = entity.x+entity.vx
        if collision.isColliding(unpackPosition(entity,entity.w,entity.h,true)) then
            local d = entity.vx/math.abs(entity.vx)/2

            if entity.vy == entity.gravity and not collision.isColliding(entity.x,entity.y-.5,entity.cx,entity.cy,entity.w,entity.h,true) then
                entity.y = entity.y-.5
            elseif d==d then
                entity.x = hfloor(entity.x+d/2)+0
                while collision.isColliding(unpackPosition(entity,entity.w,entity.h,true)) do
                    entity.x = entity.x-d
                end
                entity.vx = 0
            end
        end

        
        entity.vx = entity.vx*(1-entity.friction)

        if h~=entity.x then
            entity.moved = true
        end
        return returnevents
    end
}

function TEST()
    for k,v in pairs(level.entitiesInChunks[-1][0]) do
        print(level.entities[k].cx,level.entities[k].cy)
    end
end


local entities = {
    test = {color=1},
    thrownItem = {color=1,
        noBatch = true,
        summoned = function(entity,item)
            entity.accx,entity.gravity = 0.05,0.05
            entity.gravity = 0.07
            entity.friction = 0.1

            entity.item = item
        end,
        update = function(entity,dt)
            local a,b = entity.cx+0,entity.cy+0
            manipulate.physicsY(entity)
            manipulate.physicsX(entity)
            manipulate.updatePos(entity,a,b)

        end,
        
        draw = function(entity,x,y)
            love.graphics.draw(items.img,items[entity.item.id].quad,x,y,nil,entity.w/8)
        end
    },
    test2 = {color=2,
        w=1,h=.5,
        summoned = function(entity,signal)
            entity.accx,entity.gravity = 0.05,0.05
            entity.gravity = 0.07
            entity.friction = 0.1
            
        end,
        update = function(entity,dt)
            if not entity.customQuad then                
                entity.customQuad = love.graphics.newQuad(entityAtlas[entity.name].color*4-3,0,2,1,imageEntityPallete:getDimensions())
                entity.customQuadScaleW = .5
                entity.customQuadScaleH = 1
            end

            local a,b = entity.cx+0,entity.cy+0
            manipulate.physicsY(entity)
            manipulate.physicsX(entity)
            
            entity.countdown = entity.countdown or 0


            
            
            if entity.vy == entity.gravity then
                if entity.countdown == 0 then
                    entity.vy = -1
                    entity.countdown = 5
                end
                entity.countdown = entity.countdown-1
            end

            manipulate.updatePos(entity,a,b)
        end
    },
    player = {
        summoned = function(entity,signal)
            entity.vx,entity.vy = 0,0
            entity.friction = 0.3
            entity.maxspeedx,entity.maxspeedy = 10/tps,100/tps
            entity.accx,entity.gravity = entity.maxspeedx*.5,0.07
        end,
        update = function(entity,dt)
            local a,b = entity.cx+0,entity.cy+0
            if key.up and (entity.canJump-love.timer.getTime())>-.2 then
                do
                    local rx = hfloor(entity.x+.25) -- rounded x
                    local y = entity.y-1
                    local cx,cy = entity.cx,entity.cy
                    if 
                        (
                            (not collision.isColliding(rx,y,cx,cy,1,.5,true)) and 
                            collision.isColliding(rx-.5,y,cx,cy,1,.5,true) and
                            collision.isColliding(rx+.5,y,cx,cy,1,.5,true)
                        )
                    then
                        entity.x = rx
                    end
                end

                entity.vy = -0.50625
                entity.canJump = -1
            end
            entity.vy = math.max(math.min(entity.vy,entity.maxspeedy),-entity.maxspeedy)
            local e1 = manipulate.physicsY(entity)


            if key.left or key.right then
                entity.vx = entity.vx+((key.right and 1 or 0)+(key.left and -1 or 0))*entity.accx
                local dir = entity.vx/math.abs(entity.vx)/2
                local ry = hfloor(entity.y+.25) -- rounded y
                local x = entity.x+dir
                local cx,cy = entity.cx,entity.cy
                if 
                    (
                        (not collision.isColliding(x,ry,cx,cy,1,1,true)) and 
                        (not collision.isColliding(x-dir,ry-1,cx,cy,1,1,true)) and 
                        collision.isColliding(x,ry-1,cx,cy,1,1,true) and
                        collision.isColliding(x,ry+1,cx,cy,1,1,true)
                    )
                then
                    entity.y = ry
                    entity.x = entity.x+dir/10
                end
            end
            entity.vx = math.max(math.min(entity.vx,entity.maxspeedx),-entity.maxspeedx)

            local e2 = manipulate.physicsX(entity)


            if key.down then
                local rx = hfloor(entity.x+.25) -- rounded x
                local y = entity.y+1
                local cx,cy = entity.cx,entity.cy
                if 
                    (
                        (not collision.isColliding(rx,y,cx,cy,1,1,true)) and 
                        collision.isColliding(rx-1,y,cx,cy,1,1,true) and
                        collision.isColliding(rx+1,y,cx,cy,1,1,true)
                    )
                then
                    entity.x = rx
                end
            end


            local h = entity.x+0

            PROTOTYPE = 0

            local skip = {}



            
            manipulate.updatePos(entity,a,b)
            --print(entity.moved,entity.vx,entity.x,entity.x-h)
            
        end
    },
}


local colorPallete = {
    {{0,1,0,1},{1,0,0,1}},
    {{0,1,1,1},{1,0,1,1}},
}



local entityColor = {}

function entityColor.refresh()
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
    return love.graphics.newImage(pallete),quadPallete
end

function entityColor.addColor(value)
    table.insert(colorPallete,value)
    return #colorPallete
end
function entityColor.getColor(index)
    return colorPallete[index]
end

return {entities,entityColor}