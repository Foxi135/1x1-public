cl = require "consolua"

cl.clear()

cl.printCentered("Hello world!","-")
cl.display()

local w,h = cl.getDimensions()
cl.moveTo(0,1)
for i = 1, w do
    cl.write("_")
    cl.display()
    cl.prototypeWait(0.01)
end

local t = {"-","/","|","\\"}
cl.clear()
for i = 1, 10 do
    cl.moveTo(0,5)
    cl.removeLine()
    cl.write(string.rep(t[i%#t+1],w))
    cl.display()
    cl.prototypeWait(0.2)
end

for i = 1, w do
    cl.prototypeWait(0.01)
    cl.moveBy(-1,0)
    cl.removeChar()
    cl.display()
end

local text = "you're cute! :3"
do
    local t = {}
    for i = 1, #text do
        t[i] = string.sub(text,i,i)
    end
    text = t
end
for i = 4, 0, -1 do
    cl.moveTo(0,5)
    cl.removeLine()
    cl.printCentered(table.concat(text,string.rep(" ",i)))
    cl.prototypeWait(0.1)
    cl.display()
end


