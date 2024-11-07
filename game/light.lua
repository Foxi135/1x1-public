maximumLightLevel = 25
lightShader = love.graphics.newShader([[
    extern float level;
    extern float width;

    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, coords);
        if (pixel.a < level) {
            float x = coords.x;
            float y = coords.y;
            float minimum = (1/width);
            float maximum = (1-minimum);
            if ((x>minimum)&&(x<maximum)&&(y>minimum)&&(y<maximum)){
                vec2 offsets[4] = vec2[4](vec2(-1,0), vec2(1,0), vec2(0,-1), vec2(0,1));
                float maxAlpha = 0;
                for (int i = 0; i < 4; i++) {
                    vec4 pixel2 = Texel(texture, coords + offsets[i]*minimum);
                    if ((pixel2.a<0.5)&&(pixel2.a>0)) {
                        maxAlpha = max(maxAlpha, pixel2.a);
                    }
                }
                float a = maxAlpha*255-1;
                if (level-0.5<a) {
                    return vec4(1,1,1,max(pixel.a,a/255));
                }
            }        
        }
        return pixel;
    }
]])
lightMaskShader = love.graphics.newShader([[
    extern sampler2D lightMap;
    extern float width;
    extern float maximumLightLevel;

    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, coords);
        if (pixel.r+pixel.g+pixel.b != 0) {
            vec2 offsets[5] = vec2[5](vec2(0,0), vec2(1,0), vec2(0,-1), vec2(0,1), vec2(-1,0));
        
            float minimum = (1/width);
            float maxAlpha = 0;
            for (int i = 0; i < 5; i++) {
                vec4 pixel2 = Texel(lightMap, (offsets[i] + coords/minimum + vec2(1,1))*(1/(width+2)));
                if ((pixel2.a<0.5)&&(pixel2.a>0)) {
                    maxAlpha = max(maxAlpha, pixel2.a);
                }
            }
            float a = maxAlpha*255/maximumLightLevel;
            pixel.r = 0;
            pixel.g = 0;
            pixel.b = 0;
            pixel.a = 1-a;
        
            return pixel;
        } else {
            return vec4(0,0,0,0);
        }
    }
]])
lightBackgroundShader = love.graphics.newShader([[
    extern float width;
    extern float maximumLightLevel;

    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, coords);
        return vec4(1,1,1,pixel.a*255/maximumLightLevel*0.5);
    }
]])
sunShader = love.graphics.newShader([[
    extern float maximumLightLevel;
    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, coords);
        if (pixel.a > 0.5) {
            return vec4(0,0,0,0);
        } else {
            return vec4(1,1,1,maximumLightLevel);
        }
    }
]])
function updateCycleTimer()
    daynightcycletime = love.timer.getTime()-cyclestart
    daynightcycle = math.abs(1-(daynightcycletime%cyclelength*2)/cyclelength)
end
function updateLightInChunk(cx,cy)
    level.chunks[cx][cy].prevsunlightlevel = getSunLightLevel()
    level.chunks[cx][cy].needsLightUpdate = false
    level.chunks[cx][cy].LightMap = level.chunks[cx][cy].LightMap or love.graphics.newCanvas(level.mapSize+2,level.mapSize+2)
    level.chunks[cx][cy].LightMapMask = level.chunks[cx][cy].LightMapMask or love.graphics.newCanvas(level.mapSize*2,level.mapSize*2)
    level.chunks[cx][cy].LightMapBG = level.chunks[cx][cy].LightMapBG or love.graphics.newCanvas(level.mapSize,level.mapSize)
    level.chunks[cx][cy].LightMapMask:setFilter("nearest","nearest")
    level.chunks[cx][cy].LightMapBG:setFilter("nearest","nearest")
    local o = maximumLightLevel+1
    sunShader:send("maximumLightLevel",getSunLightLevel()/255)
    
    setColor(1,1,1)
    love.graphics.setCanvas(lightCanvas[1])
    love.graphics.clear(0,0,0,0)
    local a,b = love.graphics.getBlendMode()
    for k, v in pairs({{0,0},{1,1},{1,0},{1,-1},{0,-1},{-1,-1},{-1,0},{-1,1},{0,1}}) do
        if (level.chunks[cx+v[1]] or {})[cy+v[2]] then
            if level.chunks[cx+v[1]][cy+v[2]].shadowMask then
                love.graphics.setBlendMode("replace")
                love.graphics.setShader(sunShader)
                love.graphics.draw(level.chunks[cx+v[1]][cy+v[2]].shadowMask,o+level.mapSize*v[1],o+level.mapSize*v[2])
                love.graphics.setShader()
            end
            
            love.graphics.setBlendMode("lighten","premultiplied")
            love.graphics.draw(level.chunks[cx+v[1]][cy+v[2]].startingLightMap,o+level.mapSize*v[1],o+level.mapSize*v[2])
        end
    end
    love.graphics.setBlendMode(a,b)
    love.graphics.setCanvas()

    lightShader:send("width",level.mapSize+o*2)
    for i = maximumLightLevel, 1, -1 do
        love.graphics.setCanvas(lightCanvas[2])
        love.graphics.clear(0,0,0,0)
        lightShader:send("level",i)
        love.graphics.setShader(lightShader)
        love.graphics.draw(lightCanvas[1])
        love.graphics.setShader()
        love.graphics.setCanvas(lightCanvas[1])
        love.graphics.clear(0,0,0,0)
        love.graphics.draw(lightCanvas[2])
        love.graphics.setCanvas()
    end
    love.graphics.setCanvas(level.chunks[cx][cy].LightMap)
    love.graphics.clear({0,0,0,0})
    love.graphics.draw(lightCanvas[1],-o+1,-o+1)
    love.graphics.setCanvas()
    
    lightMaskShader:send("maximumLightLevel",maximumLightLevel)
    lightMaskShader:send("width",level.mapSize)
    lightMaskShader:send("lightMap",level.chunks[cx][cy].LightMap)
    love.graphics.setCanvas(lightCanvas[3])
    love.graphics.clear(0,0,0,0)
    love.graphics.setShader(lightMaskShader)
    love.graphics.draw(level.chunks[cx][cy].mapDrawable)
    love.graphics.setShader()

    local a,b = love.graphics.getBlendMode()
    love.graphics.setCanvas(level.chunks[cx][cy].LightMapMask)
    love.graphics.clear(0,0,0,0)
    
    love.graphics.draw(lightCanvas[3],0,0,nil,2)

    love.graphics.setShader(subtractShader)
    love.graphics.setBlendMode("darken","premultiplied")
    love.graphics.draw(level.chunks[cx][cy].rendered,0,0,nil)

    love.graphics.setBlendMode(a,b)
    love.graphics.setShader()
    love.graphics.setCanvas()

    lightBackgroundShader:send("maximumLightLevel",maximumLightLevel)
    love.graphics.setCanvas(level.chunks[cx][cy].LightMapBG)
    love.graphics.clear(0,0,0,0)
    love.graphics.setShader(lightBackgroundShader)
    love.graphics.draw(level.chunks[cx][cy].LightMap,-1,-1)
    love.graphics.setShader()
    love.graphics.setCanvas()
    if level.chunks[cx][cy].LightMapData then
        level.chunks[cx][cy].LightMapData:release()
        level.chunks[cx][cy].LightMapData = nil
    end
    level.chunks[cx][cy].LightMapData = level.chunks[cx][cy].LightMap:newImageData()
end
subtractShader = love.graphics.newShader([[
    extern float maximumLightLevel;
    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, coords);
        if (pixel.a == 0) {
            return vec4(0,0,0,0);
        } else {
            return vec4(1,1,1,1);
        }
    }
]])
function processSun(cx,cy,above)
    if not cy then
        local miny,maxy;
        for k, v in pairs(level.chunks[cx]) do
            miny = math.min(miny or k,k)
            maxy = math.max(maxy or k,k)
        end
        if not (miny and maxy) then
            print("no chunks in row "..(cx or "(falsy)\n   (not even possible to start with)"))
            return
        end
        local above = {};
        for y = miny, maxy, 1 do
            if level.chunks[cx][y] then
                above = processSun(cx,y,above)
            end
        end
        return
    end
    level.chunks[cx][cy].needSunUpdate = false
    local a = not level.chunks[cx][cy].shadowMask
    level.chunks[cx][cy].shadowMask = level.chunks[cx][cy].shadowMask or love.graphics.newCanvas(level.mapSize,level.mapSize)
    if a then level.chunks[cx][cy].shadowMask:setFilter("nearest","nearest") end
    love.graphics.setCanvas(level.chunks[cx][cy].shadowMask)
    love.graphics.clear(0,0,0,0)
    setColor(1,1,1)
    for x = 0, level.mapSize-1 do
        local y = (above[x] and 0) or level.chunks[cx][cy].highest[x]
        if y then
            love.graphics.rectangle("fill",x,y,1,level.mapSize)
        end
    end
    love.graphics.setCanvas()
    return mergeTablesByIndex({above,level.chunks[cx][cy].highest})
end
function getSunLightLevel()
    return math.ceil(daynightcycle*25)
end
function mergeTablesByIndex(inp)
    local t = {}
    for l, w in pairs(inp) do
        for k, v in pairs(w) do
            t[k] = t[k] or v
        end
    end
    return t
end
function updateShadowMaskRow(cx,cy,x,y)
    local a,b = love.graphics.getBlendMode()
    love.graphics.setCanvas(level.chunks[cx][cy].shadowMask)

    setColor(1,1,1)
    love.graphics.setBlendMode("subtract","premultiplied")
    love.graphics.rectangle("fill",x,0,1,level.mapSize)
    
    love.graphics.setBlendMode(a,b)
    if y then
        love.graphics.rectangle("fill",x,y,1,level.mapSize)
    end
    level.chunks[cx][cy].highest[x] = y

    love.graphics.setCanvas()
end