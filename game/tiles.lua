
local tiles = {
    {name="wall",model=15,light=0,opaque=1,solid=1,color=1},
    {name="red",model=15,light=0,opaque=1,solid=0,color=2},
}




setColor(1,1,1)


return {tiles,tilebyname,
    function()


ColorPallete = {{0,0,0,0},{1,1,1,1},{1,0,0,1},{0,1,0,1},{.87,.87,.87,1},{0.55,0.32,0.22,1}}


local function resolveCompatibility(glsl3code)
    local text = glsl3code..""

    if love.graphics.getSupported().glsl3 then
        text = text:gsub("_ADDITIONAL_","")
        return text
    end
    if text:find("#pragma language glsl3") then
        local tokens = {""}
        local groups = {
            " \n",
            "{}()[];,",
            "+*/=",
            "><&|%"
        }
        for i = 1, #groups do
            local l = groups[i]
            local t = {}
            for j = 1, #l do
                t[string.sub(l,j,j)] = true
            end
            groups[i] = t
        end

        local cg = 1
        local comment;
        for i = 1, #text do
            local c = string.sub(text,i,i)

            if comment then
                if c=="\n" then
                    comment = false
                end
            else
                local g = 0
                for j = 1, #groups do
                    if groups[j][c] then
                        g = j
                        if g == 2 then
                            g = i+#groups
                        end
                        break
                    end
                end
    
                if g~=1 then                    
                    if cg==g then
                        tokens[#tokens] = tokens[#tokens]..c
                        if tokens[#tokens] == "//" then 
                            comment = true 
                            table.remove(tokens,#tokens)
                        end
                    else
                        table.insert(tokens,c)
                    end
                end
                cg = g+0
            end

        end

        for k, v in pairs(tokens) do
            if v=="uint" then
                tokens[k] = "int"
            elseif string.sub(v,1,#v-1)=="uvec" then
                tokens[k] = "ivec"..string.sub(v,#v,#v)
            else
                local n = tonumber(string.sub(v,1,#v-1))
                if n and string.sub(v,#v,#v) == "u" then
                    tokens[k] = string.format("int(%d)",n)
                end
            end

        end


        local replace = {
            [">>"] = "bitshiftr(%s, %s)",
            ["<<"] = "bitshiftl(%s, %s)",
            ["&"] =  "bitand(%s, %s)",
            ["|"] =  "bitor(%s, %s)",
            ["%"] =  "mod(%s, %s)",
        }
        local count = 0
        for k, v in pairs(tokens) do
            count = count+((replace[v] and 1) or 0)
        end


        local limit = 200
        while count>0 and limit>0 do
            local maxlevel = 0
            local maxleveli = 0
            local level = 0
            for k, v in pairs(tokens) do
                level = level + (v=="(" and 1 or 0) - (v==")" and 1 or 0)
                if maxlevel<level then
                    maxleveli = k
                    maxlevel = level+0
                end
            end

            local t = {}
            local i = 0
            while maxleveli>0 do
                table.insert(t,tokens[maxleveli+i])
                if tokens[maxleveli+i] == ")" then break end
                if not tokens[maxleveli+i] then break end
                i = i+1
            end
            for i = #t-1, 1, -1 do
                table.remove(tokens,maxleveli+i)
            end
            
            if t[1] == "(" and replace[t[3]] and t[5] == ")" then
                print(inspect(t))
                tokens[maxleveli] = string.format(replace[t[3]],t[2],t[4])
                count = count-1
            else
                tokens[maxleveli] = table.concat(t," ")
            end

            limit = limit-1
        end

        

        text = table.concat(tokens," ")
        text = text:gsub("#pragma language glsl3","")
        text = text:gsub(";",";\n")
        text = text:gsub("_ADDITIONAL_",[[
            float log2(float x) {
                return log(x) / log(2.0);
            }
            int bitand(int a, int b) {
                    int result = 0;
                    int n = 1;

                    while (a > 0 || b > 0) {
                        int ba = int(mod(a, 2));
                        int bb = int(mod(b, 2));

                        result += (ba * bb) * n;

                        a /= 2;
                        b /= 2;

                        n *= 2;
                    }

                    return result;
            }
            int bitor(int a, int b) {
                    int result = 0;
                    int n = 1;

                    while (a > 0 || b > 0) {
                        int ba = int(mod(a, 2));
                        int bb = int(mod(b, 2));

                        result += (max(ba, bb)) * n;

                        a /= 2;
                        b /= 2;

                        n *= 2;
                    }

                    return result;
            }
            int bitshiftl(int a, int b) {
                return int(float(a) * pow(2.0, float(b)));
            }
            int bitshiftr(int a, int b) {
                return int(float(a) / pow(2.0, float(b)));
            }
        ]])

        return text
    end
end
renderShader = love.graphics.newShader(resolveCompatibility([[    
    #pragma language glsl3
    uniform vec4 pallete[]]..#ColorPallete..[[];
    uniform float mapSize;

    float unit = 1.0/mapSize;

    _ADDITIONAL_

    uint findFirst1(uint x) {
        return uint(log2(float((x & -x))));
    }

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        uvec4 p = uvec4(floor(Texel(tex, texture_coords)*255)); //get colors in 255

        if (p.a==0u) return vec4(0,0,0,0);

        uvec2 pixelpos = uvec2(texture_coords.x*mapSize,texture_coords.y*mapSize); //set up model and 2x2 coords
        uvec2 tilepos = uvec2(floor(vec2(pixelpos)/2)*2u);
        uint model = (p.b >> 4);

        uint index = 0u;
        index += uint(min(pixelpos.y - tilepos.y,1u)*2.0 + float(min(pixelpos.x - tilepos.x,1u)));

        if (((model >> index) & 1u) == 1u) { //model
            vec4 add = vec4(0,0,0,0);
            if ((((p.r >> 1u) & 1u) == 1u)&&(findFirst1(model)==index)) { //interactible mark
                add = vec4(0.25,0.25,0.25,0);
            }
            return pallete[p.g]+add;
        }
        return vec4(0,0,0,0);
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