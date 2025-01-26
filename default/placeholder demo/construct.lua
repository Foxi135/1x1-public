local x,y = info.player.x,info.player.y
local platform = importStructure("platform.png")
build(platform,x+platform.width/-2,y+1,0,0)
