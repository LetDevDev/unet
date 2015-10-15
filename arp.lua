local computer = require("computer")
local event = require("event")
local pack = require("serialization")
local unet = require("unet")

unet.arp.routes = {}

--arp addressing system unet, used for addressing in both managed and unmanaged networks.

--address format is in the form of numbers split by slashes, all numbers before the final slash
--are subnet addresses used for routing. Taking the address 2/3/4 we can figure out this device is
--on a subnetwork named 3, and that network is on another network: 2
--1 is a valid address
--0 is not a valid address, it is a valid subnetwork though:
--0/1 is a valid address
--4/2543/2522/33/442/88/9 is also a valid address (must be a big network to get this though!)

function unet.arp.getAddress(id)
  if unet.driver.inter[id] and unet.driver.inter[id].isAvailable then
    if unet.driver.inter[id].parent == "0" then
    
    end
  end
end

function unet.arp.checkAddr(addr)
  
end

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

