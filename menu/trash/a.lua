cl = require "consolua"

cl.setDimensions(93,45)

local w,h = cl.width,cl.height
cl.prototypeWait(0.1)
for i = 0, 2 do
    cl.moveTo(w-2,h-i)
    cl.write("###")
end
cl.moveTo(w-1,h-1)
cl.display()

local log = ""
local initx,inity = cl.getCursorPos()

while true do
    local x,y = cl.getCursorPos()
    if x~=initx or y~=inity then
        cl.moveTo(0,0)
        local dx,dy = x-initx,y-inity
        log = log..((dx>0 and "left\n") or (dx<0 and "right\n") or "")..((dy>0 and "up\n") or (dy<0 and "down\n") or "")

        initx,inity = x,y
    end
end