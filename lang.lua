function deserialize(code)
    functions.log({code},"> ")
    local tokens = {""}
    local isString = false
    local partOfString = {}
    local i = 1

    while i <= #code do
        local char = code:sub(i,i)

        if char == '"' then
            if isString then
                partOfString[#tokens] = true
                table.insert(tokens,"")
            end
            isString = not isString

        elseif isString and char=="\\" then
            i = i + 1
            tokens[#tokens] = tokens[#tokens] ..(code:sub(i, i) or "")

        elseif not isString and char==" " then
            table.insert(tokens, "")
        elseif not isString and (char=="(" or char==")") then
            table.insert(tokens,char)
            table.insert(tokens,"")
        elseif not isString and char == "[" then
            table.insert(tokens,"(")
            table.insert(tokens,"}L")
            table.insert(tokens,"")
        elseif not isString and char == "]" then
            table.insert(tokens,")")
            table.insert(tokens,"")
        elseif not isString and char == "{" then
            table.insert(tokens,"(")
            table.insert(tokens,"}R")
            table.insert(tokens,"(")
            table.insert(tokens,"")
        elseif not isString and char == "}" then
            table.insert(tokens,")")
            table.insert(tokens,")")
            table.insert(tokens,"")
        else
            tokens[#tokens] = tokens[#tokens]..char
        end
        i=i+1
    end

    local finalTokens = {}
    for i, v in ipairs(tokens) do
        if v~="" or partOfString[i] then
            table.insert(finalTokens,v)
        end
    end

    for i, v in ipairs(finalTokens) do
        local num = tonumber(v)
        local bool = ({["true"]=true,["false"]=false})[v]
        if num then
            finalTokens[i] = num
        end
        if bool ~= nil then
            finalTokens[i] = bool
        end
    end

    return parse(finalTokens)
end

function parse(tokens)
    local result = {}
    while #tokens > 0 do
        local token = table.remove(tokens,1)
        if token == "(" then
            table.insert(result, parse(tokens))
        elseif token == ")" then
            break
        else
            table.insert(result, token)
        end
    end
    return result
end

function normalizeValueType(value)
    local valueType = type(value)

    if valueType == "number" then
        return value ~= value and 0 or value -- NaN check
    elseif valueType == "string" then
        local parsedNumber = tonumber(value)
        return parsedNumber or value
    elseif valueType == "boolean" then
        return value
    elseif valueType == "table" then
        return value
    end

    return 0
end
ignore = {["}R"]=true}
function execute(code,pos)
    if type(code)~="table" then return code end
    local inputs = {}
    local name;
    for k, v in pairs(code) do
        local result;
        if type(v)=="table" and not ignore[name or ""] then
            result = execute(v,pos)
        else
            result = v
        end
        if k == 1 then
            name = result
        else
            table.insert(inputs,result)
        end
    end
    if functions[name] then return functions[name](inputs,pos) end
    if definitioninputs[name] then
        local h = {}
        for k, v in pairs(definitioninputs[name]) do
            local t = type(variables[v]) --removing potential references
            if t=="boolean" then
                h[v] = not not variables[v]
            elseif t=="number" then
                h[v] = variables[v]+0
            elseif t=="string" then
                h[v] = variables[v]..""
            end
            variables[v] = inputs[k]
        end
        local r = execute(variables[name],pos)
        for k, v in pairs(h) do
            variables[k] = v
        end
        return r
    end
    if variables[name] then return variables[name] end
end
definitioninputs = {}
variables = {}
functions = {
    log = function(inputs,decor)
        local t = {}
        for k, v in pairs(inputs) do
            if type(v) == "string" then
                t[k] = v
            else
                t[k] = inspect(v)
            end
        end
        print(unpack(t))
        table.insert(log,1,{decor=type(decor)=="string" and decor or "",value=table.concat(t,"  "),start=love.timer.getTime()})
        while #log>100 do
            log[#log] = nil
        end
    end,
    ["while"] = function(inputs,pos)
        while execute(inputs[1],pos) do
            execute(inputs[2],pos)
        end
    end,
    loop = function(inputs,pos)
        for i = 1, inputs[1] do
            execute(inputs[2],pos)
        end
    end,
    ["+"] = function(inputs)
        local result = 0
        for k, v in pairs(inputs) do
            if type(v) == "number" then
                result = result+v
            end
        end
        return result
    end,
    ["*"] = function(inputs)
        local result
        for k, v in pairs(inputs) do
            if type(v) == "number" then
                if not result then result = v+0
                else result = result*v end
            end
        end
        return result
    end,
    ["-"] = function(inputs)
        local result
        for k, v in pairs(inputs) do
            if type(v) == "number" then
                if not result then result = v+0
                else result = result-v end
            end
        end
        return result
    end,
    ["/"] = function(inputs)
        local result
        for k, v in pairs(inputs) do
            if type(v) == "number" then
                if not result then result = v+0
                else result = result/v end
            end
        end
        return result
    end,
    ["join"] = function(inputs)
        local result = ""
        for k, v in pairs(inputs) do
            result = result..(type(v)=="table" and inspect(v,{newline="", indent=""}) or tostring(v))
        end
        return result
    end,
    len = function(inputs)
        local t = type(inputs[1])
        if t == "string" or t == "table" then
            return #inputs[1]
        else
            return #(tostring(inputs[1]))
        end
    end,
    index = function(inputs)
        if type(inputs[1]) == "table" then
            return inputs[1][inputs[2]]
        elseif type(inputs[1]) == "string" and type(inputs[2]) == "number" then
            return inputs[1]:sub(inputs[2],inputs[2])
        end
    end,
    setindex = function(inputs)
        if type(inputs[1]) == "table" then
            inputs[1][inputs[2]] = inputs[3]
            return inputs[1]
        end
    end,
    ["}R"] = function(inputs) return inputs[1] end,
    ["}L"] = function(inputs) return inputs end,
    u = function(inputs) return unpack(inputs[1]) end,
    cls = function(inputs) log = {} end,
    stats = function(inputs)
        if inputs[1] == nil then
            showStats = not showStats
        else
            showStats = inputs[1]
        end
    end,
    clearvars = function()
        definitioninputs = {}
        variables = {}
    end,
    delete = function(inputs)
        for k, v in pairs(inputs) do            
            definitioninputs[k] = nil
            variables[k] = nil
        end
    end,
    var = function(inputs)
        if inputs[2] == nil then
            return variables[inputs[1]]
        else
            variables[inputs[1]] = inputs[2]
        end
    end,
    def = function(inputs)
        variables[inputs[1]] = inputs[2]
        definitioninputs[inputs[1]] = {}
        for k, v in pairs(inputs) do
            if k>2 then
                table.insert(definitioninputs[inputs[1]],v)
            end
        end
    end
}
execute(deserialize(
([[cls
(def list {
    (var a [
        "log ... - prints its inputs"
        "fly [true/false] - set/toggles players fly state"
        "position [ <x/\"_\"> <y/\"_\"> <chunk x/\"_\"> <chunk y/\"_\"> ] - tells or sets players position"
        "as <entity id> <code> - executes code positioned as an entity"
        "time [seconds] - tells or sets game time"
        "save [string: world name] - saves world. entering nothing will save the world into the folder it was loaded from"
        "loadWorld <string: world name> - loads world. will automatically restart the game too"
        "cls - clears console"
        "list - lists commands"
    ])
    (var i (len (a)))
    (loop (i) {
        (log (index (a) (i)))
        (var i (- (i) 1))
    })
} a)
]]):gsub("\n", " ")))
execute(deserialize(
([[cls
(def -- {
    (var (varname) (- (var (varname)) (n)) )
} varname n)
(def stairs {
    (var i 0)
    (var x (+ 0 (index (position) 1)))
    (var y (+ 0 (index (position) 2)))
    (loop (repeat) {
        (placeTile [255 255 255] (x)(y))
        (placeTile [255 255 255] (+ (x) 2)(- (y) 1))
        (placeTile [255 255 255] (x)(- (y) 1))
        (-- x 1)
        (-- y 2)
    })
} repeat x y i)


(def ++ {
    (var (varname) (+ (var (varname)) (n)) )
} varname n)

(def fill {
    (var ix (+ 0 (x)))
    (loop (w) {
        (var iy (+ 0 (y)))
        (loop (h) {
            (placeTile (tile) (ix) (iy))
            (++ iy 1)
        })
        (++ ix 1)
    })
} tile x y w h  ix iy)
]]):gsub("\n", " ")))
--fill [1 0 21] 142 145 20 10
--fill [0 0 0] 142 145 20 20