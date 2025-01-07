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
                chunk.spriteBatch[entity.spriteBatchType]:set(entity.drawID,entity.quad,entity.x,entity.y,entity.r,entity.customQuadScaleW,entity.customQuadScaleH,entity.ox,entity.oy)
            else
                entity.drawID = chunk.spriteBatch[entity.spriteBatchType]:add(entity.quad,entity.x,entity.y,entity.r,entity.customQuadScaleW,entity.customQuadScaleH,entity.ox,entity.oy)
            end
        end
    end,
    updatePos = function(entity,prevcx,prevcy) -- gl reading this lmao
        if not entity.moved then
            return
        end
        entity.moved = false
        local _,_,cx,cy = utils.fixCoords(unpackPosition(entity))

        entity.x,entity.y,entity.cx,entity.cy = utils.fixCoords(unpackPosition(entity))

        local cx,cy = entity.cx,entity.cy
        local chunk = (level.chunks[cx] or {})[cy]
        if prevcx ~= cx or prevcy ~= cy then
            level.entitiesInChunks[prevcx][prevcy][entity.id] = nil
            level.entitiesInChunks[cx] = level.entitiesInChunks[cx] or {}
            level.entitiesInChunks[cx][cy] = level.entitiesInChunks[cx][cy] or {}
            level.entitiesInChunks[cx][cy][entity.id] = true
            if entity.drawID and level.entitiesInChunks[prevcx] and level.entitiesInChunks[prevcx][prevcy] then
                level.chunks[prevcx][prevcy].spriteBatch[entity.spriteBatchType]:set(entity.drawID,0,0,0,0)
                chunk.spriteBatchEscapes[entity.spriteBatchType] = (chunk.spriteBatchEscapes[entity.spriteBatchType] or 0)+1
                entity.drawID = nil
            end
        end
        if chunk.spriteBatch and not entity.noBatch then
            if entity.drawID then
                chunk.spriteBatch[entity.spriteBatchType]:set(entity.drawID,entity.quad,entity.x,entity.y,entity.r,entity.customQuadScaleW,entity.customQuadScaleH,entity.ox,entity.oy)
            else
                entity.drawID = chunk.spriteBatch[entity.spriteBatchType]:add(entity.quad,entity.x,entity.y,entity.r,entity.customQuadScaleW,entity.customQuadScaleH,entity.ox,entity.oy)
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
    default = {
        color = 1,
        w=1, h=1,
        customQuadScaleW=.5, customQuadScaleH=.5,
        spriteBatchType = "entity",
    },
    test = {color=1},
    thrownItem = {
        isColliding = true,
        color = 1,
        w=.5, h=.5,
        customQuadScaleW=1/8, customQuadScaleH=1/8, 
        spriteBatchType = "item",

        _convert = {
            [0]=1,2,5,3,4
        },

        _rotat = {
            { [14]={.5,0,2}, [13]={1,2,2}, [7]= {-.5,2,0} },
            { [2]= {.5,0,2}, [8]= {1,2,2}, [4]= {-.5,2,0} },
            { [3]= {.5,0,2}, [10]={1,2,2}, [12]={-.5,2,0} },
            { [9]= {.5,0,2} },
        },

        summoned = function(entity,item)
            entity.accx,entity.gravity = 0.05,0.05
            entity.gravity = 0.07
            entity.friction = 0.1

            entity.item = {
                type = item.type.."",
                code = (item.code and item.code+0) or nil,
                id = (item.id and item.id+0) or nil,
                durability = (item.durability and item.durability+0) or nil,
            }
            if item.type == "tile" then
                entity.spriteBatchType = "tileitem"
            end

        end,
        update = function(entity,dt)
            if not entity.customQuad then
                if entity.item.type == "tile" then
                    entity.customQuadScaleW = .25
                    entity.customQuadScaleH = .25

                    local m = pixel.getProperty(entity.item.code,"model")
                    local g = utils.modelsGrouped[m] or 0

                    entity.customQuad = tileBatchQuads[pixel.getProperty(entity.item.code,"color")+1][entityAtlas.thrownItem._convert[g]]
                    
                    local rotat = entityAtlas.thrownItem._rotat
                    print(g,m)
                    if rotat[g] and rotat[g][m] then
                        local t = rotat[g][m]
                        entity.r,entity.ox,entity.oy = t[1]*math.pi,t[2],t[3]
                        print(entity.r,entity.ox,entity.oy)
                    end
                    if g == 0 then
                        entity.customQuadScaleW = .5
                        entity.customQuadScaleH = .5
                    end
                else
                    entity.customQuad = items[entity.item.id].quad
                    entity.ox,entity.oy = 2,2
                end
            end

            local a,b = entity.cx+0,entity.cy+0
            manipulate.physicsY(entity)
            manipulate.physicsX(entity)
            manipulate.updatePos(entity,a,b)

        end,
        
    },
    test2 = {color=2,
        w=.5,h=.5,
        customQuadScaleW = .25,
        customQuadScaleH = .25,
        summoned = function(entity,signal)
            entity.accx,entity.gravity = 0.05,0.05
            entity.gravity = 0.07
            entity.friction = 0.1
        end,
        update = function(entity,dt)
            --[[if not entity.customQuad then                
                entity.customQuad = love.graphics.newQuad(entityAtlas[entity.name].color*4-3,0,2,1,imageEntityPallete:getDimensions())
                entity.customQuadScaleW = .5
                entity.customQuadScaleH = 1
            end]]
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
        isColliding = true,
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
            
        end,
        onCollision = function(self,with)
            if not with.ALL[1] then return end

            for k, v in pairs(with.thrownItem) do
                local e = level.entities[v]
                local result = nil
                local found = false
                for i = 1, 32 do --8*4 = 32
                    local slot = self.content[i]
                    if not slot then
                        result = result or i
                    end
                    if slot and slot.amount<level.stackLimit and slot.type==e.item.type and slot.code==e.item.code and slot.id==e.item.id and ((not slot.durability) and not e.item.durability) then
                        result = i
                        found = true
                        break
                    end
                end
                local mininv
                if not found then
                    print("A")
                    for i = 1, 32 do
                        local slot = utils.atInvPos(self.content,i)
                        if slot == 0 then
                            mininv = i
                            break
                        end
                    end
                end
                if result then
                    if not self.content[result] then
                        self.content[result] = e.item
                        self.content[result].amount = 1
                        self.content[result].invpos = mininv
                        table.sort(self.content,utils.sortContent)
                    else
                        self.content[result].amount = self.content[result].amount+1
                    end
                    utils.deleteEntity(e.id)
                end
            end
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