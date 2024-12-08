local popup = {}

incursor = nil;
local inventoryColumns = 5
popup.entries = {
    inventory = {
        creative = {
            gridw=5,gridh=10,size=40,
            cascade={itemslot={x=1,w=1,h=1,padding=4,labelpadding=1,text_size=1,textoffx=1}},
            align=function(w,h,fw,fh)
                return fw/2,(fh-h)/2
            end,
            {
                tag="itemslot",id="cretive0_0",x=0,y=0,
                tile={code=2147549680,color={1,1,1},label="wall", model={true,true,true,true},count=1/0}
            },
            {
                tag="itemslot",id="cretive1_0",x=1,y=0,
                tile={code=pixel.setProperty(2147549680,"color",1),color={0,1,1},label="wall", model={true,true,true,true},count=1/0}
            }
        },
        start = function(data)
            local A = {gridw=5,gridh=10,size=40,cascade={itemslot={x=1,w=1,h=1,padding=4,labelpadding=1,text_size=1,textoffx=1}},align=function(w,h,fw,fh)
                return fw/2-w,(fh-h)/2
            end}
            
            local left = {}
            for k,v in ipairs(data[1]) do
                if v.type == "tile" then
                    local tilecolor = pixel.getProperty(v.code,"color")+1
                    tilecolor = {
                        ColorPallete[tilecolor][1]+0,
                        ColorPallete[tilecolor][2]+0,
                        ColorPallete[tilecolor][3]+0,
                    }
                    local tilemodel = pixel.getProperty(v.code,"model")
                    tilemodel = {
                        getBits(tilemodel,0,1) == 1,
                        getBits(tilemodel,1,1) == 1,
                        getBits(tilemodel,2,1) == 1,
                        getBits(tilemodel,3,1) == 1,
                    }
                    left[v.invpos] = {label=tiles[v.id].name.."",count=v.amount+0,color=tilecolor,model=tilemodel,code=v.code+0}
                end
            end

            local i = 0
            for y=1,8 do
                for x=1,4 do
                    i = i+1
                    local slot = {tag="itemslot",id="inv"..x..y,x=x,y=y-math.floor(1/y),tile=left[i]}

                    table.insert(A,slot)
                end
            end

            table.insert(A,{tag="button",linewidth=0,color={0,0,0,0},hovercolor={.9,.1,.1,.2},w=1,h=7,x=0,y=1,label="",padding=4,clicked=function() incursor=nil end})
            table.insert(A,{tag="image",src="ui/trash2.png",w=1,h=1,x=0,y=4,color={.9,.1,.1,.2}})

            popup.active = {ui.process(A),ui.process(popup.entries.inventory.creative),close=popup.entries.inventory.close}
        end,
        close = function()
            local i = 0
            local entity = level.entities[playerID]
            --[[entity.content = {
                {type = "item", id = "testitem", amount = 50, invpos=7},
                {type = "tile", id = 1, amount = 50, invpos=5, code = pixel.setProperty(pixel.setProperty(pixel.setProperty(pixel.big(0,0,0,0),"color",1),"model",15),"solid",1)},
            }]]

            local inventory = {}
            for y=1,8 do
                for x=1,4 do
                    i = i+1
                    local tile = popup.active[1].dynamic["inv"..x..y].tile
                    if tile then
                        table.insert(inventory,
                            {type="tile",id=pixel.getProperty(tile.code,"id")+1,amount=tile.count+0,code=tile.code+0,invpos=i+0}
                        )
                    end
                end
            end

            entity.content = inventory
        end
    }
}

function popup.evoke(name,data)
    popup.entries[name].start(data)
end

function popup.close()
    if popup.active.close then
        popup.active.close()
    end
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
    setColor(0,0,0,.5)
    love.graphics.rectangle("fill",0,0,love.graphics.getDimensions())
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