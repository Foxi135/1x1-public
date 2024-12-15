local popup = {}

incursor = nil;
local inventoryColumns = 5
popup.entries = {
    inventory = {
        initcreative = function(inserttiles)
            local t = {
                gridw=5.5,gridh=10,size=40,
                cascade={itemslot={x=1,w=1,h=1,padding=4,labelpadding=1,text_size=1,textoffx=1}},
                align=function(w,h,fw,fh)
                    return fw/2+20,(fh-h)/2
                end,
            }

            for i, v in ipairs(inserttiles) do
                local x,y = (i-1)%4+1,math.ceil(i/4)-1
                print(pixel.encodeModel(v.tilemodel),inspect(v.tilemodel))
                table.insert(t,{
                    tag="itemslot",id="creative"..x.."/"..y,x=x-1,y=y,
                    tile={
                        label=tiles[v.id].name.."",
                        count=1/0,
                        color={
                            ColorPallete[v.color+1][1]+0,
                            ColorPallete[v.color+1][2]+0,
                            ColorPallete[v.color+1][3]+0,
                        },
                        model=v.tilemodel,
                        code=pixel.defineTile{
                            model  = pixel.encodeModel(v.tilemodel),
                            id     = v.id-1,
                            color  = v.color,
                            solid  = v.solid,
                            opaque = v.opaqe,
                            mark   = v.mark,
                            light  = v.light,
                        }
                    }
                }) 
            end
            print(inspect(t))
            return t
        end,
        start = function(data)
            local A = {gridw=5.5,gridh=10,size=40,cascade={itemslot={x=1,w=1,h=1,padding=4,labelpadding=1,text_size=1,textoffx=1}},align=function(w,h,fw,fh)
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

            table.insert(A,{tag="button",linewidth=0,color={0,0,0,0},hovercolor={.9,.1,.1,.2},w=1,h=10,x=0,y=0,label="",padding=4,clicked=function() incursor=nil end})
            table.insert(A,{tag="image",src="ui/trash2.png",w=1,h=1,x=0,y=4,color={.9,.1,.1,.2}})
            table.insert(A,{tag="label",x=1,y=9,w=4,h=0,
                align=function(w,h,fw,fh)
                    return (fw-w)/2,0
                end,
                label=string.format("%s to pick up\n%s to place down\nhold %s to move all",keyR(_G.data.keyBinding.place),keyR(_G.data.keyBinding.unplace),keyR(_G.data.keyBinding.sprint))
            })
            
            table.insert(A,{tag="line",x=5.5,y=0,w=0,h=10})
            table.insert(A,{tag="line",x=1,y=1.5,w=4,h=0})

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