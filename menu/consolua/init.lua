local consolua = {reset="\27[m",isWindows=package.config:sub(1, 1) == "\\"}
local utf8 = require "utf8"

local RENDER = ""
function consolua.write(t)
    RENDER = RENDER..t
end
local write = consolua.write

local colornames = {"black","red","green","yellow","blue","magenta","cyan","white"}

local start,reset = "\27[",consolua.reset
local codes = {}
codes.foreground = {}
codes.background = {}
codes.style = {bold=1,italic=3,underline=4}

local add_to = "foreground" --just setting up (lazy to type it all out)
for j = 0, 1 do
    local off = 29 +10*j
    local prefix = ""
    for _ = 1, 2 do
        for i = 1, 8 do
            codes[add_to][prefix..colornames[i]] = i+off
        end
        off = 89 +10*j
        prefix = "bright"
    end
    add_to = "background"
end

if consolua.isWindows then -- if windows
    os.execute("chcp 65001>nul")
end

function consolua.colored(...)
    local t = {...}
    local result = ""
    
    for i = 1, #t do
        local v = t[i]
        local n = {}

        if v.background then
            table.insert(n,codes.background[v.background])
        end
        if v.foreground then
            table.insert(n,codes.foreground[v.foreground])
        end
        if v.style then
            if type(v.style) == "table" then
                for j = 1, #v.style do
                    table.insert(n,codes.style[v.style[j]])
                end
            else
                table.insert(n,codes.style[v.style])
            end
        end

        result = result..  start.. table.concat(n,";").."m"..v[1]..reset
    end
    return result
end

function consolua.style(background,foreground,style)
    local n = {}
    if background then
        table.insert(n,codes.background[background])
    end
    if foreground then
        table.insert(n,codes.foreground[foreground])
    end
    if style then
        if type(style) == "table" then
            for j = 1, #style do
                table.insert(n,codes.style[style[j]])
            end
        else
            table.insert(n,codes.style[style])
        end
    end
    return start.. table.concat(n,";").."m"
end
consolua.clearStyle = reset..""

function consolua.clear()
    write("\27[2J\27[1;1f")
end

consolua.width, consolua.height = 0,0
function consolua.updateDimensions()
    if consolua.isWindows then -- windows
        local handle = io.popen('dimensions.bat')
        local result = handle:read("*a")
        handle:close()

        local width,height,buffer = result:match("(%d+)x(%d+)x(%d+)")
        consolua.width,consolua.height = width+0,height+0
        return width+0, height+0
    else -- linux
        --todo
        error("linux not supported. sry!")
    end
end
function consolua.setDimensions(width,height)
    if consolua.isWindows then -- windows
        os.execute(string.format("mode con cols=%d lines=%d > nul",width,height))
        consolua.width,consolua.height = width+0,height+0
    else -- linux
        --todo
        error("linux not supported. sry!")
    end
end
function consolua.getCursorPos()
    local handle = io.popen('cursor.bat')
    local result = handle:read("*a")
    handle:close()

    local x,y = result:match("^%[%[(%d+);(%d+)R")
    return x,y
end

function consolua.display()
    io.write(RENDER)
    RENDER = ""
end

function consolua.moveTo(x,y)
    write(string.format("\27[%d;%dH",y or 0,x or 0))
end
function consolua.moveBy(x,y)
    if x ~= 0 then
        write(string.format("\27[%d%s",math.abs(x),x>0 and "C" or "D"))
    end
    if y ~= 0 then
        write(string.format("\27[%d%s",math.abs(y),y>0 and "A" or "B"))
    end
end
function consolua.removeChar(count)
    write(string.format("\27[%dP",count or 1))
end
function consolua.removeLine()
    write("\27[2K")
end
function consolua.printCentered(text,fill)
    local w = consolua.width
    local t = string.rep(fill or " ",math.floor((w-utf8.len(text))/2))
    write(string.format("%s%s%s\n",t,text,t))
end
function consolua.printRight(text,fill)
    local w = consolua.width
    local t = string.rep(fill or " ",w-utf8.len(text))
    write(string.format("%s%s\n",t,text))
end
function consolua.prototypeWait(seconds)
    local endAt = os.clock()+seconds
    while os.clock()<endAt do end
end

return consolua