
local items = {
    offset = 0xffffffff, --idk if i will ever need it
    -- wait, what was it for in the first place?
    texsize = 8,
    {name="iron axe", color=5, texture=1, maxdur=300},
    {name="iron pickaxe", color=5, texture=2, maxdur=300},
    {name="iron shovel", color=5, texture=3, maxdur=300},
    {name="iron sword", color=5, texture=4, maxdur=300},
    {name="apple", texture=5},
    {name="summon", texture=6, used=function(item,tilepos, place,unplace)
        local angle = (cam.handAngle or 0)+0
        local player = level.entities[playerID]
        local entityID = utils.summonEntity("test2",player.x+0,player.y+0,player.cx+0,player.cy+0)
        local entity = level.entities[entityID]
        entity.vx,entity.vy = math.cos(angle)*2,math.sin(angle)

        if unplace then
            entity.vx,entity.vy = 0,0
            entity.x,entity.y,entity.cx,entity.cy = unpack(tilepos)
            entity.y = entity.y+0.01
            entity.permanent = true
        end
    end},
}





local textureimgdata = love.image.newImageData("textures.png")

local colorpixels = {}
local x = 0
local mainShade;
while x<items.texsize do
    local r,g,b,a = textureimgdata:getPixel(x,0)
    if a==1 then
        local shade = {0,0,0}
        if mainShade then
            shade = {r-mainShade[1],g-mainShade[2],b-mainShade[3]}
        else
            mainShade = {r,g,b}
        end
        colorpixels[pixel.big(r,g,b,a)] = shade
    else
        break
    end
    x = x+1
end



local map = love.image.newImageData(#items*(items.texsize+2),items.texsize)
for i, item in ipairs(items) do
    local sx = (i-1)*(items.texsize+2)+1
    map:mapPixel(function(x,y)
        local r,g,b,a = textureimgdata:getPixel(x-sx+items.texsize*item.texture,y)
        local shade = colorpixels[pixel.big(r,g,b,a)]
        local c = ColorPallete[item.color or 1]
        if shade then
            return unpack({c[1]+shade[1],c[2]+shade[2],c[3]+shade[3] ,a})
        else
            return r,g,b,a
        end
    end,sx,0,items.texsize,items.texsize)
end

items.img = love.graphics.newImage(map)

for i, item in ipairs(items) do
    local sx = (i-1)*(items.texsize+2)+1
    items[i].quad = love.graphics.newQuad(sx,0,items.texsize,items.texsize,items.img)
end

return items