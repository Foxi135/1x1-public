local popup = {}

incursor = nil;
local inventoryColumns = 5
popup.entries = {
    inventory = {
        start = function(data)
            local A = {gridw=10,gridh=10,size=40,cascade={itemslot={x=1,w=1,h=1,padding=4,labelpadding=1,text_size=1,textoffx=1}},align="center"}
            
            for x=1,4 do
                for y=1,8 do
                    if y == 1 then
                        table.insert(A,{tag="itemslot",tile={model={
                            math.random(0,1)==0,math.random(0,1)==0,math.random(0,1)==0,math.random(0,1)==0
                        },color={1,0,1},count=2,label="test item"},id="inv"..x..y,x=x,y=y-1})
                    else
                        table.insert(A,{tag="itemslot",id="inv"..x..y,x=x,y=y})
                    end
                end
            end

            table.insert(A,{tag="button",linewidth=0,color={0,0,0,0},hovercolor={.9,.1,.1,.2},w=1,h=7,x=0,y=1,label="",padding=4,clicked=function() incursor=nil end})
            table.insert(A,{tag="image",src="ui/trash2.png",w=1,h=1,x=0,y=4,color={.9,.1,.1,.2}})

            popup.active = {ui.process(A)}
        end
    }
}

function popup.evoke(name,data)
    popup.entries[name].start(data)
end

function popup.close()
    popup.active = nil
end
function popup.extradraw()
    local tile = incursor
    if (not tile) or (not tile.model) then
        return
    end 
    local bw = 15
    local p = 4
    local p2 = p*2
    local bx,by = love.mouse.getPosition()

    setColor(0,0,0,.75)
    love.graphics.rectangle("fill",bx-bw-p,by-bw-p,bw*2+p2,bw*2+p2)
    setColor(tile.color)

    for i = 0, 3 do
        if tile.model[i+1] then
            local fx,fy = bx+(i%2-1)*bw,by+math.floor(i/2-1)*bw
            love.graphics.rectangle("fill",fx,fy,bw,bw)
        end
    end

    local labelpadding = 1
    local cw = font:getWidth(tile.count or 1)+labelpadding*2

    local x,y = love.mouse.getPosition()
    local fx,fy = x-bw,y-bw
    setColor(0,0,0,0.75)
    love.graphics.rectangle("fill",fx,fy,cw-1,fh-2)
    setColor(1,1,1)
    love.graphics.print(tile.count,fx,fy)
end

function popup.draw()
    if not popup.active then return end
    for k, v in ipairs(popup.active) do
        ui.draw(popup.active[k])
    end
    if popup.extradraw then
        popup.extradraw()
    end
end

function popup.event(name,a,b,c,d,e,f)
    if not popup.active then return end
    if not ui[name] then return end
    for k, v in ipairs(popup.active) do
        ui[name](popup.active[k],a,b,c,d,e,f)
    end
end


return popup