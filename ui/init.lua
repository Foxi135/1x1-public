local ui = {}

local function inBox(mx,my,x,y,w,h)
    return mx>x and my>y and mx<x+w and my<y+h
end

local fontscale = 3

function ui.process(frame)
    local drawInstructions = {}
    local events = {}
    local dynamic = {}
    for i, e in ipairs(frame) do
        local r,e = ui.elements[e.tag](table.merge((frame.cascade or {})[e.tag] or {},e),frame.size)
        if r then
            table.insert(drawInstructions,r)
        end
        if e then
            table.insert(events,{box=e.box,hold=e.hold,id=r[3]})
            for k, v in pairs(e) do
                if type(v) == "function" then
                    events[k] = events[k] or {}
                    table.insert(events[k],{i=#events,func=v})
                end
            end
        end
        if r[3] then
            dynamic[r[3]] = r.dynamic or {}
        end
    end
    print(inspect(events))
    return {clicked=true,w=frame.size*frame.gridw,h=frame.size*frame.gridh,items_per_row=frame.items_per_row,size=frame.size,draw=drawInstructions,dynamic=dynamic,translate=type(frame.align)=="function" and frame.align or ui.aligns[frame.align or "none"],events=events,hideOverflow=frame.hide_overflow,scrollY=frame.scrollY and 0 or nil}
end
function ui.draw(processed)
    local mousedown = love.mouse.isDown(1)
    processed.clicked = mousedown and not processed.clicked
    local mx,my = love.mouse.getPosition()
    local alreadyHovered
    love.graphics.push()
    local tx,ty = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())

    setColor(1,0,0)
    love.graphics.rectangle("line",tx,ty,processed.w,processed.h)

    if processed.hideOverflow then
        love.graphics.setScissor(tx,ty,processed.w,processed.h)
    end

    local scrollX,scrollY = processed.scrollX or 0, processed.scrollY or 0
    if scrollX~=0 then
        error("X SCROLL IS NOT SUPPORTED!")
    end
    local translateX,translateY = tx-scrollX,ty-scrollY
    love.graphics.translate(math.floor(translateX),math.floor(translateY))
    mx,my = mx-tx+scrollX,my-ty+scrollY

    local entireBox
    if not processed.entireBox then
        entireBox = {x=0,y=0,w=0,h=0}
    end

    if processed.items_per_row and not entireBox then
        local pr = processed.items_per_row --per row
        local gridScroll = math.ceil(scrollY/processed.size)
        for i = math.max(1,gridScroll*pr), math.min(#processed.draw,(gridScroll+processed.h/processed.size)*pr), 1 do
            local v = processed.draw[i]
            local hover;
            if v.hover and not alreadyHovered then
                local x,y,w,h;
                if ui.boxes[v[1]] then
                    x,y,w,h = ui.boxes[v[1]](v[2],v[3] and processed.dynamic[v[3]])
                else
                    x,y,w,h = unpack(v[2])
                end
                if inBox(mx,my,x,y,w,h) then
                    hover = {mx,my}
                    alreadyHovered = v.event
                end
            end
            ui.drawElements[v[1]](v[2],v[3] and processed.dynamic[v[3]],hover,translateX,translateY)
        end
    else        
        for i, v in ipairs(processed.draw) do
            local x,y,w,h;
            if ui.boxes[v[1]] then
                x,y,w,h = ui.boxes[v[1]](v[2],v[3] and processed.dynamic[v[3]])
            else
                x,y,w,h = unpack(v[2])
            end
            if entireBox then
                entireBox.x = math.min(x,entireBox.x)
                entireBox.y = math.min(y,entireBox.y)
                entireBox.w = math.max(w+x,entireBox.w)
                entireBox.h = math.max(h+y,entireBox.h)
            end
            if not (processed.hideOverflow and (x>processed.w or x<-w) and (y>processed.h or y<-h)) then
                local hover;
                if v.hover and not alreadyHovered then
                    if inBox(mx,my,x,y,w,h) then
                        hover = {mx,my}
                        alreadyHovered = v.event
                    end
                end
                ui.drawElements[v[1]](v[2],v[3] and processed.dynamic[v[3]],hover,translateX,translateY)
            end
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
        if ((not alreadyHovered) and inBox(mx,my,processed.w,scrollY,10,processed.h) and processed.clicked) or (processed.dragScrollY and mousedown) then
            processed.scrollY = (my-scrollY)/processed.h*(entireBox.h-processed.h)
            processed.dragScrollY = true

            processed.scrollY = math.min(processed.scrollY,processed.entireBox.h-processed.h)
            processed.scrollY = math.max(processed.scrollY,0)
        else
            processed.dragScrollY = false
        end
    end
    love.graphics.pop()
    --love.graphics.rectangle("line",tx,ty,processed.w,processed.h)
    processed.clicked = mousedown
end
ui.drawElements = {
    button = function(static,dynamic,hover)
        local x,y,w,h,label,fontscale,o,textoffx,color,hovercolor,linewidth = unpack(static)
        setColor(color)
        if hover then
            setColor(hovercolor)
        end
        love.graphics.rectangle("fill",x,y,w,h)
        setColor(1,1,1)
        if linewidth ~= 0 then            
            love.graphics.setLineWidth(linewidth)
            love.graphics.rectangle("line",x,y,w,h)
            love.graphics.setLineWidth(1)
        end
        love.graphics.print(label,x+(w-font:getWidth(label)*fontscale)/2+textoffx,y+o,nil,fontscale)
    end,
    itemslot = function(static,dynamic,hover)
        local x,y,w,h,_,fontscale,_,hh,labelpadding = unpack(static)
        local tile = dynamic.tile

        local label = " "..(dynamic.tile and dynamic.tile.label or "").." "
        local hw = font:getWidth(label)*fontscale+labelpadding*2
        
        setColor(1,1,1)
        love.graphics.rectangle("line",x,y,w,h)

        if tile then
            if tile.model then
                setColor(tile.color)
                local bw,bh = w/2-1,h/2-1
                local bx,by = x+1,y+1
                for i = 0, 3 do
                    if tile.model[i+1] then
                        local fx,fy = bx+(i%2)*bw,by+math.floor(i/2)*bh
                        love.graphics.rectangle("fill",fx,fy,bw,bh)
                    end
                end
            end
            if tonumber(tile.count) and tile.count~=1 then
                local rx,ry = x+labelpadding,y+labelpadding

                local cw = font:getWidth(tile.count or 1)
                setColor(0,0,0,0.75)
                love.graphics.rectangle("fill",rx,ry,cw+labelpadding*2-1,fh-2)
                setColor(1,1,1)
                love.graphics.print(tile.count,rx+labelpadding,ry)

            end 
        end
        
        if hover then
            setColor(1,1,1,.2)
            love.graphics.rectangle("fill",x,y,w,h)
            if label and #label>2 then
                setColor(0,0,0)
                love.graphics.rectangle("fill",x,y,-hw,hh)
                setColor(1,1,1)
                love.graphics.print(label,x+labelpadding-hw,y+labelpadding,nil,fontscale)
            end
        end

    end,
    img = function(static,dynamic)
        local x,y,w,h,img = unpack(static)
        setColor(1,1,1)
        love.graphics.draw(img,x,y,nil,w,h)
    end,
    label = function(static,dynamic)
        local x,y,w,h,label,s,oy = unpack(static)
        setColor(1,1,1)
        love.graphics.printf((dynamic and dynamic.label) or label,x,y,w,nil,nil,s)
    end,
    input = function(static,dynamic,hover,tx,ty)
        local fx,fy,w,h,padding,fontscale = unpack(static)
        local field = dynamic.field
        setColor(1,1,1)
        love.graphics.rectangle("line",fx+2,fy+2,w-4,h-4,4)
        
        do
            local prevscissor = {love.graphics.getScissor()}
            
            if static[7]>1 then
                setColor(1,1,1)
                local h = h-padding*2
                local s = math.min(1,h/field:getTextHeight())
                love.graphics.rectangle("fill",fx+w-padding,fy+padding+field:getScrollY()*s,2,s*h)
            end

            local fx,fy = fx+padding,fy+(h/static[7]-fh2)/2
            
            love.graphics.setScissor()
            love.graphics.setScissor(fx+tx-1,fy+ty-1,w-padding*2+2,h-padding*2+2)
            

            love.graphics.setFont(font2)
            setColor(0,0,1,(dynamic.focused and 1) or .2)
            for _, x, y, w, h in field:eachSelection() do
                love.graphics.rectangle("fill", fx+x, fy+y, w, h)
            end
    
            setColor(1,1,1)
            for _, text, x, y in field:eachVisibleLine() do
                love.graphics.print(text, fx+x, fy+y)
            end
            do
                if not dynamic.focused then
                    setColor(1,1,1,.2)
                end
                local x, y, h = field:getCursorLayout()
                love.graphics.rectangle("fill", fx+x-1, fy+y, 1, h)
            end

            love.graphics.setScissor(unpack(prevscissor))
            love.graphics.setFont(font)
        end
    end, 
}
ui.boxes = {
    label = function(static,dynamic)
        local x,y,w,h,label,s,oy = unpack(static)
        if dynamic then
            local _,l = font:getWrap(label,w)
            return x,y,w,math.max(h,oy+#l*fh*s)
        else
            return x,y,w,h
        end
    end
}
ui.elements = {
    itemslot = function(e,size)
        local padding = e.padding or 0
        local fontscale = (e.text_size or 1)+0
        local label = " "..(e.label or "").." "
        local labelpadding = e.labelpadding or e.padding or 0
        local x,y,w,h = e.x*size+padding,
                        e.y*size+padding,
                        e.w*size-padding*2,
                        e.h*size-padding*2
        
        local hoverheight = fh*fontscale+labelpadding*2


        return {
            "itemslot",
            {x,y,w,h,label.."",fontscale,nil,hoverheight,labelpadding},
            dynamic = {tile=e.tile},
            e.id,
            hover = true
        },{
            click = function(hold,dyn,_,_,button)
                if (not incursor) and (not dyn.tile) then
                    return
                end
                if button == 3 then return end

                dyn.tile = dyn.tile or {label=incursor.label,color=incursor.color,model=incursor.model,count=0, code=incursor.code}
                incursor = incursor or {label=dyn.tile.label,color=dyn.tile.color,model=dyn.tile.model,count=0, code=dyn.tile.code}

                local match = incursor.type == dyn.tile.type and incursor.code == dyn.tile.code

                do
                    local left, right; -- puts items from the left side to right

                    if button == 1 then
                        left,right = incursor.count+0, dyn.tile.count+0
                    else
                        left,right = dyn.tile.count+0, incursor.count+0
                    end

                    if match and left>0 then
                        right = right+1
                        if left == 1/0 then
                            if popup.key.sprint then
                                right = level.stackLimit+0
                            end
                        else
                            left = left-1
                            if popup.key.sprint then
                                right = right+left
                                left = 0
                            end
                        end
                        if right>level.stackLimit then
                            local b = right-level.stackLimit
                            right = right-b
                            left = left+b
                        end
                    elseif xor(left==0,right==0) then
                        local a = incursor
                        incursor = dyn.tile
                        dyn.tile = a
                    end

                    if button == 1 then
                        incursor.count,dyn.tile.count = left, right
                    else
                        dyn.tile.count,incursor.count = left, right
                    end
                end

                dyn.tile = dyn.tile.count >= 1 and dyn.tile or nil 
                incursor = incursor.count >= 1 and incursor or nil 
            end,
            box = {x,y,w,h},
            hold = e.hold
        }
    end,
    button = function(e,size)
        local fontscale = (e.text_size or 1)+0
        local padding = e.padding or 0
        local x,y,w,h = e.x*size+padding,
                        e.y*size+padding,
                        e.w*size-padding*2,
                        e.h*size-padding*2

        local o = (h-fh*fontscale)/2
        return {
            "button",
            {x,y,w,h,e.label.."",fontscale,o,e.textoffx or 0,e.color or {0,0,0,.2},e.hovercolor or {1,1,1,.2},e.linewidth or 1},
            hover = true,
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
            "img",
            {x,y,w,h,img}
        }
    end,
    label = function(e,size)
        local fontscale = e.text_size or 1
        local x,y,w,h = e.x*size, e.y*size, e.w*size, e.h*size
        local ox,oy = ui.aligns[e.align or "none"](font:getWidth(e.label)*fontscale,fh*fontscale,w,h)
        local _,l = font:getWrap(e.label,w)
        return {
            "label",
            {x+ox,y+oy,w,math.max(h,oy+#l*fh*fontscale),e.label,fontscale,oy},
            e.id
        }
    end,
    input = function(e,size)
        local fontscale = e.text_size or 1
        local x,y,w,h = e.x*size, e.y*size, e.w*size, e.h*size
        local ox,oy = ui.aligns[e.align or "none"](font:getWidth(e.label)*fontscale,fh*fontscale,w,h)
        local field = InputField(e.label)
        field:setFont(font2)
        field:setText(e.label or "")
        if e.h>1 then
            field:setType("multiwrap")
        end
        local fw,fh = w-e.padding*2,h-e.padding*2
        field:setDimensions(fw,fh)
        return {
            "input",
            {x,y,w,h,e.padding,fontscale,e.h+0},
            e.id,
            dynamic = {field=field}
        },{
            box={x+e.padding,y+e.padding,fw,fh},
            hold={FOCUSED=false},
            click = function(hold,dyn,mx,my,button,presscount)
                dyn.field:mousepressed(mx,my,button,presscount)
            end,
            mousereleased = function(hold,dyn,mx,my,button)
                dyn.field:mousereleased(mx,my,button)
            end,
            mousewheel = function(hold,dyn,x,y)
                dyn.field:wheelmoved(x,y)
            end,
            mousemovedover = function(hold,dyn,mx,my)
                dyn.field:mousemoved(mx,my)
            end,
            textinput = function(hold,dyn,t)
                dyn.field:textinput(t)
            end,
            keypressed = function(hold,dyn,key,isRepeat)
                dyn.field:keypressed(key,isRepeat)
            end,
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

function ui.mousepressed(processed,x,y,button,presscount)

    if not processed.events.click then
        return
    end
    
    local a,b = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    local mx,my = x-a,y-b
    if not inBox(mx,my,0,0,processed.w,processed.h) then
        return
    end
    my = my+(processed.scrollY or 0)
    --[[for k, v in pairs(processed.events) do
        if v.click and inBox(mx,my,unpack(v.box)) then
            v.click(v.hold)
            break
        end
    end]]
    for k, v in ipairs(processed.events.click) do
        local e = processed.events[v.i]
        local a,b,c,d = unpack(e.box)
        if inBox(mx,my,a,b,c,d) then
            v.func(e.hold,e.id and processed.dynamic[e.id], mx-a,my-b,button,presscount)
            if e.hold and e.hold.FOCUSED == false then
                processed.events[v.i].hold.FOCUSED = true
                processed.dynamic[e.id].focused = true
            end
        else
            if e.hold and e.hold.FOCUSED then
                processed.events[v.i].hold.FOCUSED = false
                processed.dynamic[e.id].focused = false
            end
        end
    end
end

function ui.mousereleased(processed,x,y,button)
    if not processed.events.mousereleased then
        return
    end

    local a,b = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    local mx,my = x-a,y-b
    my = my+(processed.scrollY or 0)

    for k, v in ipairs(processed.events.mousereleased or {}) do
        local e = processed.events[v.i]
        if (not e.hold) or e.hold.FOCUSED ~= false then
            local a,b,c,d = unpack(e.box)
            v.func(e.hold,e.id and processed.dynamic[e.id], mx-a,my-b,button)
        end
    end
end

function ui.wheelmoved(processed,x,y)
    local a,b = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    local mx,my = love.mouse.getX()-a,love.mouse.getY()-b
    if not inBox(mx,my,0,0,processed.w,processed.h) then
        return
    end

    for k, v in ipairs(processed.events.mousewheel or {}) do
        local e = processed.events[v.i]
        local a,b,c,d = unpack(e.box)
        if inBox(mx,my,a,b,c,d) then
            v.func(e.hold,e.id and processed.dynamic[e.id],x,y)
            return
        end
    end

    if not processed.scrollY then
        return
    end

    processed.scrollY = processed.scrollY-y*processed.size*.4
    processed.scrollY = math.min(processed.scrollY,processed.entireBox.h-processed.h)
    processed.scrollY = math.max(processed.scrollY,0)
end

function ui.mousemoved(processed,x,y)
    if not processed.events.mousemovedover then
        return
    end
    local a,b = processed.translate(processed.w,processed.h,love.graphics.getWidth(),love.graphics.getHeight())
    local mx,my = love.mouse.getX()-a,love.mouse.getY()-b
    if not inBox(mx,my,0,0,processed.w,processed.h) then
        return
    end
    my = my+(processed.scrollY or 0)
    for k, v in ipairs(processed.events.mousemovedover or {}) do
        local e = processed.events[v.i]
        if (not e.hold) or e.hold.FOCUSED ~= false then
            local a,b,c,d = unpack(e.box)
            if inBox(mx,my,a,b,c,d) then
                v.func(e.hold,e.id and processed.dynamic[e.id], mx-a,my-b)
                return
            end
        end
    end
end

function ui.textinput(processed,t)
    if not processed.events.textinput then
        return
    end
    for k, v in ipairs(processed.events.textinput or {}) do
        local e = processed.events[v.i]
        if (not e.hold) or e.hold.FOCUSED ~= false then
            v.func(e.hold,e.id and processed.dynamic[e.id],t)
        end
    end
end

function ui.keypressed(processed,key,isRepeat)
    if not processed.events.keypressed then
        return
    end
    for k, v in ipairs(processed.events.keypressed or {}) do
        local e = processed.events[v.i]
        if (not e.hold) or e.hold.FOCUSED ~= false then
            v.func(e.hold,e.id and processed.dynamic[e.id],key,isRepeat)
        end
    end
end

function table.merge(t1,t2)
    local t = {}
    for k,v in pairs(t1) do t[k] = v end
    for k,v in pairs(t2) do t[k] = v end
    return t
end


return ui