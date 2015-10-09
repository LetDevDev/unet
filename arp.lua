local computer = require("computer")
local event = require("event")
local pack = require("serialization")
local unet = require("unet")

unet.routes = {}

--arp addressing system unet, in some applications this will not
--be as useful, but generally a device will want to have at least
--one arp destination.

--address format is in the form of numbers split by slashes
--1 is a valid address
--4/2543/2522/33/442/88/9 is also a valid address (must be a big network to get this though!)

function unet.arp.scan(id,type,filter)
  if not id then
    id = unet.resolveID()
  end
  unet.driver.inter[id].ubroadcast("data0","ARP_REQUEST",)
end

function unet.arp.linkParent(id,)

end

function unet.send(address,flag,data)
  if unet.routes[address] then
    local route = unet.routes[address]
    unet.driver.inter[route.id].usend(route.hw,flag,pack.serialize({dest=address,
      source=unet.driver.inter[route.id].routeAddr,data=data}))
  end
end

