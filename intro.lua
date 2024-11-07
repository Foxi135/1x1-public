local frame = 0
local endFrame = 31
local fps = 30
local start
local function load()
    start = love.timer.getTime()
end
local movie = love.graphics.newImage("intro.png")
local bgShader = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex,texture_coords);
        return vec4(color.rgb,pixel.r*color.a);
    }
]])


local w,h = 480,360
return {
    load = function()
    end,
    draw = function()
        do
            love.graphics.setShader(bgShader)
            local anim = math.min(endFrame,frame)
            local x,y = -math.floor(anim/16)*w,-(anim%16)*(h+1)
            local ww,wh = love.graphics.getDimensions()
            local ox,oy = math.floor((ww-w)/2),math.floor((wh-h)/2)
            love.graphics.setScissor(ox,oy,w,h)
            setColor(1,1,1,(6-frame+anim)/5)
            love.graphics.draw(movie,x+ox,y+oy)
            love.graphics.setScissor()
            love.graphics.setShader()
        end
    end,
    update = function()
        if load then
            load()
            load = nil
        end
        frame = math.floor(fps*(love.timer.getTime()-start))
    end
}