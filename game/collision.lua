local fixc,getprop,gett = utils.fixCoords,pixel.getProperty,utils.getTile
local floor,hfloor,ceil = math.floor,math.halfFloor,math.ceil

local CATCHE = {}
return {
    isColliding = function(x,y,cx,cy,w,h,anySolid,catch) --anySolid should be true in physics function. for events it should be false. catch is passed in for physics too, before moving the player it checks what tiles player is in. this list will then be passed into this collision function
        local colliding = {}
        PROTOTYPE = (PROTOTYPE or 0)+1 -- for counting, it is here just for debugging

        local xs, ys = hfloor(x), hfloor(y)
        local xe, ye = xs+w -(x%.5==0 and .5 or 0), ys+h -(y%.5==0 and .5 or 0)
        local rx = ceil(xe-xs+1)
        --local catch = catch or {}
        for ox = xs, xe, .5 do
            for oy = ys, ye, .5 do
                local fox,foy = floor(ox),floor(oy) 
                --    fox :3

                local i = utils.encodePosition(fox,foy,cx,cy)
                local c = CATCHE[i]
                if c ~= 0 then
                    local solid,model,big;
                    local mi = (ox%1)*2+(oy%1)*4
                    if c then
                        solid,model = c[1],c[2]
                    else
                        big = gett(fixc(fox,foy,cx,cy))
                        solid = getprop(big,"solid") == 1
                        model = getprop(big,"model")
                        CATCHE[i] = {solid,model}
                    end
    
                    if getBits(model,mi,1) == 1 then
                        if anySolid and solid then
                            return true
                        end
                        if not anySolid then
                            table.insert(colliding,{x=ox,y=oy,solid=solid,big=big,cx=cx,cy=cy})
                            CATCHE[i] = 0
                        end
                    end
                end
            end
        end
        return (not anySolid) and colliding--,catch
    end,
    resetCatche = function()
        CATCHE = {}
    end,
    removeFromCatche = function(ox,oy,cx,cy)
        CATCHE[utils.encodePosition(ox,oy,cx,cy)] = nil
    end
}