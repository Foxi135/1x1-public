cl = require "consolua"

function box(t)
    local result = ""
    local last = #t
    local maxlen = 0
    for k, v in ipairs(t) do
        if k == 1 or k == last then
            maxlen = math.max(maxlen,#string.format("< %s >   ",v))
        else
            maxlen = math.max(maxlen,#string.format(" %i: %s  ",k,v))
        end
    end
    for k, v in ipairs(t) do
        if k == 1 then
            local add = string.format("< %s >",v)
            result = result.."┌".. add ..string.rep("─",maxlen-#add) .."┐\n"
        elseif k == last then
            local add = string.format("< %s >",v)
            result = result.."└" ..string.rep("─",maxlen-#add).. add .."┘\n"
        else
            local add = string.format(" %i: %s",k-1,v)
            result = result.. "│" ..add ..string.rep(" ",maxlen-#add) .."│\n"
        end
    end
    return result
end

--[[cl.write(cl.colored({
    [[
      /¯¯¯¯¯¯|
     /       |
    `¯¯¯|    |
        |    |
    |¯¯¯      ¯¯¯|
    |____________|

    \¯¯¯¯\  /¯¯¯¯/    /¯¯¯¯¯¯|
     \    \/    /    /       |
      \        /    `¯¯¯|    |
      /        \        |    |
     /    /\    \   |¯¯¯      ¯¯¯|
    /____/  \____\  |____________|
] ]
, foreground="cyan"},{string.rep(" ",27).."by Tenony",style={"italic"}}).."\n\n\n")]]
local text = [[
 
    /¯¯¯¯¯¯|                      
   /       |                      
  ´¯¯¯|    |                      
      |    |                      
  |¯¯¯      ¯¯¯|                  
  |____________|                  
                                  
  \¯¯¯¯\  /¯¯¯¯/    /¯¯¯¯¯¯|      
   \    \/    /    /       |      
    \        /    ´¯¯¯|    |      
    /        \        |    |      
   /    /\    \   |¯¯¯      ¯¯¯|  
  /____/  \____\  |____________|  

]]
cl.clear()
cl.updateDimensions()
cl.write(cl.style(nil,"brightblue"))
for s in text:gmatch("[^\r\n]+") do
    cl.printCentered(s)
    cl.prototypeWait(0.1)
    cl.display()
end
cl.printCentered(cl.clearStyle..cl.style(nil,nil,{"italic"}).."                         by Tenony")
cl.write(cl.clearStyle)

local worlds = {"test","sdfjkhg","bahbahbahbahbahbah","you're cute!"}
do
    local t = {"select world (1 to "..#worlds..")"}
    for i = 1, #worlds do
        table.insert(t,worlds[i])
    end
    table.insert(t,'"new" / "exit"')
    cl.write(box(t).."\n\n")
end
cl.display()
while true do
    io.write((#worlds==0 and "" or ("(1 to "..#worlds..") / "))..'"new" / "exit" > ')
    local input = io.read()
    if input == "new" then
        io.write('Name your new world\n(text) / "exit" > ')
        local input = io.read()

        break
    elseif input == "exit" then
        print("case b")
        break
    elseif not tonumber(input) then
        cl.removeLine(2)
        cl.write("not a valid input\n")
        cl.display()
    elseif not worlds[input+0] then
        cl.removeLine(2)
        cl.write("world "..input.." is not in the list\n")
        cl.display()
    else
        print("case c - "..worlds[input+0])
        break
    end
end