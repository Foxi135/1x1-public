local ui = {}

local function inBox(mx,my,x,y,w,h)
    return mx>x and my>y and mx<x+w and my<y+h
end

local fontscale = 3

function ui.process(frame)
    local drawInstructions = {}
    local events = {}
    for i, e in ipairs(frame) do
        local r,e = ui.elements[e.tag](table.merge((frame.cascade or {})[e.tag] or {},e),frame.size)
        if r then
            for i = 1, #r do
                table.insert(drawInstructions,r[i])
            end
        end
        if e then
            table.insert(events,e)
        end
    end
    return {w=frame.size*frame.gridw,h=frame.size*frame.gridh,draw=drawInstructions,translate=type(frame.align)=="function" and frame.align or ui.aligns[frame.align or "none"],events=events,hideOverflow=frame.hide_overflow,scrollY=frame.scrollY and 0 or nil}
end
function ui.draw(processed)
    local mx,my = love.mouse.getPosition()
    local alreadyHovered
    love.graphics.push()

    local tx,ty = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    if processed.hideOverflow then
        love.graphics.setScissor(tx,ty,processed.w,processed.h)
    end
    local scrollX,scrollY = processed.scrollX or 0, processed.scrollY or 0
    love.graphics.translate(tx-scrollX,ty-scrollY)
    mx,my = mx-tx+scrollX,my-ty+scrollY

    local entireBox
    if not processed.entireBox then
        entireBox = {x=0,y=0,w=0,h=0}
    end

    for i, v in ipairs(processed.draw) do
        if v[3] then setColor(v[3]) end
        local x,y,w,h = unpack(v.wrap or {})
        if not v.wrap then
            local _
            _,x,y,w,h = unpack(v[2])
        end
        if entireBox then
            entireBox.x = math.min(x,entireBox.x)
            entireBox.y = math.min(y,entireBox.y)
            entireBox.w = math.max(w+x,entireBox.w)
            entireBox.h = math.max(h+y,entireBox.h)
        end
        if not (processed.hideOverflow and (x>processed.w or x<-w) and (y>processed.h or y<-h)) then
            if v.hover and not alreadyHovered then
                if inBox(mx,my,x,y,w,h) then
                    setColor(v.hover)
                    alreadyHovered = v.event
                end
            end
            love.graphics[v[1]](unpack(v[2]))
        end
    end
    entireBox = entireBox or processed.entireBox
    processed.entireBox = entireBox

    love.graphics.setScissor()
    setColor(1,1,1)
    local s = processed.h/entireBox.h
    if processed.scrollY and (s<1) then
        local y = scrollY+scrollY*s
        love.graphics.rectangle("fill",processed.w,y,10,s*processed.h)
        love.graphics.rectangle("line",processed.w,scrollY,10,processed.h)
        if (not alreadyHovered) and inBox(mx,my,processed.w,scrollY,10,processed.h) and love.mouse.isDown(1) then
            processed.scrollY = (my-scrollY)/processed.h*(entireBox.h-processed.h)
        end
    end
    love.graphics.pop()
    --love.graphics.rectangle("line",tx,ty,processed.w,processed.h)
end
ui.draw = {
    button = function(v,hold)
        
    end
}
ui.elements = {
    button = function(e,size)
        local fontscale = e.text_size or 1
        local padding = e.padding or 0
        local x,y,w,h = e.x*size+padding,
                        e.y*size+padding,
                        e.w*size-padding*2,
                        e.h*size-padding*2

                        local o = (h-fh*fontscale)/2
        return {
            {
                "rectangle",
                {"fill",x,y,w,h},
                {0,0,0,.2},
                hover={1,1,1,.2},
            },
            {
                "rectangle",
                {"line",x,y,w,h},
                {1,1,1},
            },
            {
                "print",
                {e.label,x+(w-font:getWidth(e.label)*fontscale)/2,y+o,nil,fontscale},
                {1,1,1},
                wrap={x,y,w,h},
            }
        },e.clicked and {
            click = e.clicked,
            box = {x,y,w,h},
            hold = e.hold
        } or nil
    end,
    image = function(e,size)
        local img = love.graphics.newImage(e.src)
        if e.filter then
            img:setFilter(e.filter,e.filter)
        end
        local padding = e.padding or 0
        local x,y,w,h = e.x*size+padding,
                        e.y*size+padding,
                        (e.w*size-padding*2)/img:getWidth(),
                        (e.h*size-padding*2)/img:getHeight()
        return {
            {
                "draw",
                {img,x,y,nil,w,h},
                {1,1,1},
                wrap={x,y,w,h},
            },
        }
    end,
    label = function(e,size)
        local fontscale = e.text_size or 1
        local x,y,w,h = e.x*size, e.y*size, e.w*size, e.h*size
        local ox,oy = ui.aligns[e.align or "none"](font:getWidth(e.label)*fontscale,fh*fontscale,w,h)
        local _,l = font:getWrap(e.label,w)
        return {
            {
                "printf",
                {e.label,x+ox,y+oy,w,nil,nil,fontscale},
                {1,1,1},
                wrap={x,y,w,math.max(h,oy+#l*fh*fontscale)},
                dynamic=e.id,
            }
        }
    end,
}
ui.aligns = {
    center = function(w,h,frameW,frameH)
        return (frameW-w)/2,(frameH-h)/2
    end,
    none = function()
        return 0,0
    end
}

function ui.mousepressed(processed,x,y,button)
    if button ~= 1 then
        return
    end

    local a,b = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    local mx,my = x-a,y-b

    for k, v in pairs(processed.events) do
        if v.click and inBox(mx,my,unpack(v.box)) then
            v.click(v.hold)
        end
    end
end

function ui.wheelmoved(processed,x,y)
    if not processed.scrollY then
        return
    end
    local a,b = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    local mx,my = love.mouse.getX()-a,love.mouse.getY()-b
    if not inBox(mx,my,0,0,processed.w,processed.h) then
        return
    end
    processed.scrollY = processed.scrollY-y
    processed.scrollY = math.min(processed.scrollY,processed.entireBox.h-processed.h)
    processed.scrollY = math.max(processed.scrollY,0)
end

function table.merge(t1,t2)
    local t = {}
    for k,v in pairs(t1) do t[k] = v end
    for k,v in pairs(t2) do t[k] = v end
    return t
end


return ui