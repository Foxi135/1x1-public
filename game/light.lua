local light = {shader={},maxLevel = 15}
local maxLevel = light.maxLevel

local resolveCompatibility = require "game.resolveShaders"

light.shader.extractLight = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float a = mod(floor(pixel.b * 255.0),16);
        return vec4(1.0,1.0,1.0, a / 255.0); //vec4(1.0,1.0,1.0,15.0 / 255.0);//vec4(1.0,1.0,1.0, a / 255.0);
    }
]])

light.shader.render = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        return vec4(0.0,0.0,0.0,1.0 - pixel.a * 255.0 / 15.0);
    }
]])

light.shader.solidMask = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float a = 1.0 - mod(pixel.r * 255.0 / 4.0, 2);
        return vec4(a,a,a,a);
    }
]])

light.shader.spreadLight = love.graphics.newShader([[
    uniform float width;

    const vec2 off[4] = vec2[4](vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(0.0, -1.0));

    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float maxa = pixel.a * 255.0;
        
        for (int i = 0; i < 4; i++) {
            maxa = max(maxa, Texel(tex, coords + off[i] / width).a * 255.0 - 1.0);
        }

        return vec4(1.0,1.0,1.0, maxa / 255.0);
    }
]])

for k, v in pairs(light.shader) do
    print(k.."\n"..v:getWarnings( ))
end

local canvas = {}

function light.createProcessCanvases()
    while canvas[1] do canvas[1]:release() table.remove(canvas,1) end
    for i = 1, 3 do
        canvas[i] = love.graphics.newCanvas(maxLevel*2+level.mapSize,maxLevel*2+level.mapSize)
    end
end


function light.update(cx,cy)
    if not level.chunks[cx] or not level.chunks[cx][cy] then return end
    setColor(1,1,1)

    if not canvas[1] then light.createProcessCanvases() end
    local blendmode,premultiplied = love.graphics.getBlendMode()

    local chunk = level.chunks[cx][cy]

    light.shader.spreadLight:send("width",canvas[1]:getWidth())

    love.graphics.setBlendMode("replace","premultiplied")

    love.graphics.setCanvas(canvas[3])
    love.graphics.setShader(light.shader.solidMask)
    for x = -1, 1 do
        for y = -1, 1 do
            if level.chunks[x+cx] and level.chunks[x+cx][y+cy] then
                love.graphics.draw(level.chunks[x+cx][y+cy].mapDraw,maxLevel+level.mapSize*x,maxLevel+level.mapSize*y,nil,0.5)
            end
        end
    end

    love.graphics.setCanvas(canvas[1])
    love.graphics.setShader(light.shader.extractLight)
    for x = -1, 1 do
        for y = -1, 1 do
            if level.chunks[x+cx] and level.chunks[x+cx][y+cy] then
                love.graphics.draw(level.chunks[x+cx][y+cy].mapDraw,maxLevel+level.mapSize*x,maxLevel+level.mapSize*y,nil,0.5)
            end
        end
    end

    local a,b;
    for i = 1, maxLevel, 1 do
        a,b = i%2+1, (i+1)%2+1
        love.graphics.setCanvas(canvas[a])
        love.graphics.setBlendMode("replace","premultiplied")
        love.graphics.setShader(light.shader.spreadLight)
        love.graphics.draw(canvas[b])
        love.graphics.setShader()
        if i~=maxLevel then
            love.graphics.setBlendMode("multiply","premultiplied")
            --love.graphics.draw(canvas[3])
        end
    end

    love.graphics.setBlendMode("replace","premultiplied")
    love.graphics.setCanvas(chunk.lightDraw)
    love.graphics.setShader(light.shader.render)
    love.graphics.draw(canvas[a],-maxLevel,-maxLevel)
    love.graphics.setShader()


    
    love.graphics.setCanvas()
    love.graphics.setBlendMode(blendmode,premultiplied)
end

function light.draw(x,y,cx,cy)
    love.graphics.draw(level.chunks[cx][cy].lightDraw,x,y)
end

return light