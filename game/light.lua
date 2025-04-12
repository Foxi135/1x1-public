local light = {shader={},maxLevel = 15}
local maxLevel = light.maxLevel


local resolveCompatibility = require "game.resolveShaders"

light.shader.extractLight = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float a = mod(pixel.b * 255.0, 16.0) / 255.0;
        return vec4(1,1,1,a);
    }
]])
light.shader.render = love.graphics.newShader([[
    uniform float width;

    #ifdef GL_ES
        vec2 off(int i) {
            if (i == 0) return vec2(-1.0, 0.0);
            if (i == 1) return vec2(0.0, 1.0);
            if (i == 2) return vec2(1.0, 0.0);
            return vec2(0.0, -1.0);
        }
    #else
        const vec2 off[4] = vec2[4](vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(0.0, -1.0));
    #endif

    
    
    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float maxa = pixel.a * 255.0;

        if (pixel.a == 0.0) {
            for (int i = 0; i < 4; i++) {
                float neighborAlpha = Texel(tex, coords + (
                    #ifdef GL_ES
                        off(i)
                    #else 
                        off[i]
                    #endif
                ) / width).a * 255.0;

                maxa = max(maxa, neighborAlpha);
            }
        }

        float a = maxa / 15.0;
        return vec4(a, a, a, 1.0);
    }
]])

light.shader.solidMask = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float a = 1.0 - mod(floor(pixel.r * 255.0 / 4.0), 2.0);
        return vec4(a, a, a, a);
    }
]])


light.shader.spreadLight = love.graphics.newShader([[
    uniform float width;

    #ifdef GL_ES
        vec2 off(int i) {
            if (i == 0) return vec2(-1.0, 0.0);
            if (i == 1) return vec2(0.0, 1.0);
            if (i == 2) return vec2(1.0, 0.0);
            return vec2(0.0, -1.0);
        }
    #else
        const vec2 off[4] = vec2[4](vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(0.0, -1.0));
    #endif


    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        float maxa = pixel.a * 255.0;

        for (int i = 0; i < 4; i++) {
            float neighbor = Texel(tex, coords + (
                #ifdef GL_ES
                    off(i)
                #else 
                    off[i]
                #endif
            ) / width).a * 255.0 - 1.0;

            maxa = max(maxa, neighbor);
        }

        return vec4(1.0, 1.0, 1.0, maxa / 255.0);
    }
]])



light.shader.sunLightStrips = love.graphics.newShader([[
    uniform float width;

    float a = 15.0/255.0;

    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);

        if (pixel.b == 1.0) { return vec4(0.0); }

        float threshold = pixel.r * 255.0 * 255.0 + pixel.g * 255.0 - 1.0;
        if (pixel.g != 0.0 && threshold < coords.y * width) { return vec4(0.0); }

        return vec4(1.0, 1.0, 1.0, a);
    }
]])


light.shader.sunShader = love.graphics.newShader([[
    uniform float width;

    const vec4 bg = vec4(1.0) * 0.2;

    vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);

        if (pixel.b == 1.0) { return bg; }

        float threshold = pixel.r * 255.0 * 255.0 + pixel.g * 255.0 - 1.0;
        if (pixel.g != 0.0 && threshold < coords.y * width) { return bg; }

        return color;
    }
]])



local canvas = {}

function light.createProcessCanvases()
    while canvas[1] do canvas[1]:release() table.remove(canvas,1) end
    for i = 1, 3 do
        canvas[i] = love.graphics.newCanvas(maxLevel*2+level.mapSize,maxLevel*2+level.mapSize)
    end
    light.shader.spreadLight:send("width",canvas[1]:getWidth())
    light.shader.render:send("width",canvas[1]:getWidth())
    light.shader.sunLightStrips:send("width",level.mapSize)
    light.shader.sunShader:send("width",level.mapSize)
end

local lastcx,lastcy

function light.update(cx,cy)
    --print(cx,cy)
    
    if not level.chunks[cx] or not level.chunks[cx][cy] then return end
    setColor(1,1,1)

    local blendmode,premultiplied = love.graphics.getBlendMode()

    local chunk = level.chunks[cx][cy]


    love.graphics.setBlendMode("replace","premultiplied")

    if not (lastcx==cx and lastcy==cy) then
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
        love.graphics.setShader(light.shader.sunLightStrips)
        love.graphics.setBlendMode("lighten","premultiplied")
        for x = -1, 1 do
            for y = -1, 0 do
                if level.chunks[x+cx] and level.chunks[x+cx][y+cy] then
                    love.graphics.draw(level.chunks[x+cx][y+cy].sunLight,maxLevel+level.mapSize*x,maxLevel+level.mapSize*y,nil,1,level.mapSize)
                end
            end
        end
        love.graphics.setCanvas()

        --require"nativefs".write("jhadshkb.png",canvas[1]:newImageData():encode("png"))

        --lastcx,lastcy = cx+0,cy+0
    end


    local a,b;
    for i = 1, maxLevel, 1 do
        a,b = i%2+1, (i+1)%2+1
        love.graphics.setCanvas(canvas[a])
        love.graphics.setBlendMode("replace","premultiplied")
        love.graphics.setShader(light.shader.spreadLight)
        love.graphics.draw(canvas[b])
        love.graphics.setShader()
        love.graphics.setBlendMode("multiply","premultiplied")
        love.graphics.draw(canvas[3])
    end

    love.graphics.setBlendMode("replace","premultiplied")
    love.graphics.setCanvas(chunk.lightDraw)
    love.graphics.setShader(light.shader.render)
    love.graphics.draw(canvas[a],-maxLevel,-maxLevel)
    love.graphics.setShader()


    
    love.graphics.setCanvas()
    love.graphics.setBlendMode(blendmode,premultiplied)
end

function light.scanSunColumn(x,map,sunLightArray,sunLightArrayAbove)
    local min = 0
    for y = 0, level.mapSize-1 do
        if pixel.getProperty(pixel.big(map:getPixel(x,y)),"solid") == 1 then -- CHANGE SOLID TO OPAQUE
            min = y+1
            break
        end
    end
    local b = ((sunLightArrayAbove[x] or 0) == 0) and ((sunLightArray[x] or 0) > level.mapSize and 1 or 0) or 1
    setColor(math.floor(min/255)/255,(min%255)/255,b,1)
    sunLightArray[x] = min+(level.mapSize+1)*b
    love.graphics.draw(pixel.bit,x,0)
    return math.min(1,b+min)
end

function light.generateNewSunLight(cx,cy)
    local sunLightArray = {}
    local sunLightArrayAbove = (level.chunks[cx][cy-1] or {}).sunLightArray or {}
    local map = level.chunks[cx][cy].map
    local sunLight = level.chunks[cx][cy].sunLight
    love.graphics.setCanvas(sunLight)
    love.graphics.setBlendMode("replace","premultiplied")
    love.graphics.setShader()
    for x = 0, level.mapSize-1 do
        light.scanSunColumn(x,map,sunLightArray,sunLightArrayAbove)
    end
    love.graphics.setCanvas()
    level.chunks[cx][cy].sunLightArray = sunLightArray
end




function love._draw()
    if parts.loaded ~= "game" then return end
    local cx,cy = -1,0
    love.graphics.setBlendMode("replace","premultiplied")
    love.graphics.setShader(light.shader.sunLightStrips)
    love.graphics.draw(level.chunks[cx][cy].sunLight,0,0,nil,1,level.mapSize)

end




return light