local popup = {}

local inventoryColumns = 5
popup.entries = {
    inventory = {
        start = function(data)

            popup.active = {ui.process({
                
            })}
        end
    }
}

popup.active = nil

function popup.evoke(name,data)
    popup.entries[name].start(data)
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