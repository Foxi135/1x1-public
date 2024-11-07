
function table.hasContent(table)
    for k, v in pairs(table) do
        return true
    end
end

function math.halfFloor(x)
    return x-x%.5
end
function math.halfCeil(x)
    return x-x%.5+.5
end

ColorPallete = {{0,0,0,0},{1,1,1,1},{1,0,0,1},{0,1,0,1},{0,0,1,1}}
renderShader = love.graphics.newShader([[    
    #pragma language glsl3
    uniform vec4 pallete[]]..#ColorPallete..[[];
    uniform float mapSize;

    float unit = 1.0/mapSize;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        uvec4 p = uvec4(floor(Texel(tex, texture_coords)*255)); //get colors in 255

        if (p.a==0u) {
            return vec4(0,0,0,0);
        }

        uvec2 pixelpos = uvec2(texture_coords.x*mapSize,texture_coords.y*mapSize); //set up model and 2x2 coords
        uint model = p.b>>4;

        uint index = 0u;
        index += (pixelpos.y % 2u)*2u + (pixelpos.x % 2u);

        if (((model>>index)&1u) == 1u) { //model
            vec4 add = vec4(0,0,0,0);
            if (((p.r&1u) == 1u)&&(((p.r>>3)&3u)==index)) { //interactible mark
                add = vec4(0.25,0.25,0.25,0);
            }
            return pallete[p.g]+add;
        }
        return vec4(0,0,0,0);
    }
]])
renderShader:send("pallete",unpack(ColorPallete))

function getBits(number,start,len)
    return math.floor(number/(2^start)) % (2^len)
end

pixel = {properties = {id={21,10},color={8,6},solid={16,1},opaque={18,1},mark={16,1},model={4,4},light={0,4}}}
function pixel.getProperty(big,name)
    local a = pixel.properties[name]
    return getBits(big,a[1],a[2])
end
function pixel.setProperty(big,name,value)
    local a = pixel.properties[name]
    local b = big-getBits(big,a[1],a[2])
    return big+value*(2^a[1])
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
pixel.pixel = love.image.newImageData(2,2)
pixel.pixel:mapPixel(function()
    return 1,1,1,1
end)
pixel.pixel = love.graphics.newImage(pixel.pixel)

pixel.entity1 = love.image.newImageData(2,2)
pixel.entity1:setPixel(0,0,1,1,1)
pixel.entity1:setPixel(1,1,1,1,1)
pixel.entity1 = love.graphics.newImage(pixel.entity1)

pixel.entity2 = love.image.newImageData(2,2)
pixel.entity2:setPixel(0,1,1,1,1)
pixel.entity2:setPixel(1,0,1,1,1)
pixel.entity2 = love.graphics.newImage(pixel.entity2)
