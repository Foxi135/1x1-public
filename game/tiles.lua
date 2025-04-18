
local tiles = {
    {name="wall",model=15,light=0,opaque=1,solid=1,color=1},
    {name="red",model=15,light=0,opaque=1,solid=0,color=2},
    {name="light",model=15,light=15,opaque=0,solid=0,color=6},
}




setColor(1,1,1)


return {tiles,tilebyname,
    function()
        ColorPallete = {{0,0,0,0},{1,1,1,1},{1,0,0,1},{0,1,0,1},{.87,.87,.87,1},{0.55,0.32,0.22,1},{1,0.882,0.6078,1}}


        local resolveCompatibility = require "game.resolveShaders"
        if renderShader then
            renderShader:release()
            renderShader = nil
        end
        renderShader = love.graphics.newShader(resolveCompatibility([[    
            #pragma language glsl3
            uniform vec4 pallete[]]..#ColorPallete..[[];
            uniform float mapSize;

            
            
            _ADDITIONAL_
            
            uint findFirst1(uint x) {
                return uint(log2(float((x & -x))));
            }
                
            vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                float unit = 1.0/mapSize;

                uvec4 p = uvec4(floor(Texel(tex, texture_coords)*255.0)); //get colors in 255

                if (p.a==0u) return vec4(0.0);

                vec2 pixelpos = floor(vec2(texture_coords.x*mapSize,texture_coords.y*mapSize)); //set up model and 2x2 coords
                vec2 tilepos = floor(vec2(pixelpos)/2.0)*2.0;
                uint model = (p.b >> 4);

                uint index = 0u;
                index += uint(min(pixelpos.y - tilepos.y,1.0)*2.0 + min(pixelpos.x - tilepos.x,1.0));

                if (((model >> index) & 1u) == 1u) { //model
                    vec4 add = vec4(0.0);
                    if ((((p.r >> 1u) & 1u) == 1u)&&(findFirst1(model)==index)) { //interactible mark
                        add = vec4(0.25,0.25,0.25,0.0);
                    }
                    return pallete[p.g]+add;
                }
                return vec4(0.0);
            }
        ]]))
        renderShader:send("pallete",unpack(ColorPallete))

        do
            local template = love.graphics.newImage("tile map batch template.png")
            local canvas = love.graphics.newCanvas(4*#ColorPallete,4)

            love.graphics.setCanvas(canvas)
            for i, v in ipairs(ColorPallete) do
                setColor(v)
                love.graphics.draw(template,(i-1)*4)
            end
            love.graphics.setCanvas()

            tileBatchMap = love.graphics.newImage(canvas:newImageData())
            template:release()
            canvas:release()
        end

        do
            tileBatchQuads = {}
            local template = love.graphics.newImage("tile map batch template.png")
            local canvas = love.graphics.newCanvas(4*#ColorPallete,4)

            love.graphics.setCanvas(canvas)
            for i, v in ipairs(ColorPallete) do
                setColor(unpack(v))
                local x = (i-1)*4
                love.graphics.draw(template,x)
                table.insert(tileBatchQuads,{ -- sorted by amount of tiles and alternatives
                    love.graphics.newQuad(x+1,1,1,1,canvas:getDimensions()),
                    love.graphics.newQuad(x+1,1,2,2,canvas:getDimensions()),
                    love.graphics.newQuad(x+2,1,2,2,canvas:getDimensions()),
                    love.graphics.newQuad(x+1,2,2,2,canvas:getDimensions()),
                    love.graphics.newQuad(x+2,2,2,2,canvas:getDimensions()),
                })
            end
            love.graphics.setCanvas()

            tileBatchMap = love.graphics.newImage(canvas:newImageData())
            template:release()
            canvas:release()
        end



    end
}