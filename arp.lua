local computer = require("computer")
local event = require("event")
local os = require ("os")
local pack = require("serialization")
local unet = require("unet")

unet.arp = {routes = {}}

--arp addressing system for unet, used for addressing in both managed and unmanaged networks.
--basically is the actual core of unet, as most modules will now depend on this.
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
      print("getting address for unmanaged network on ",id)
      while true do
        math.randomseed(os.time())
        local addr = math.random(65535)
        print("attempting to assign address ",addr," to interface ",id)
        unet.arp.scan(id,"0/"..addr)
        while true do
        print("loop")
        local message = {event.pull(5,"unet_hw_message")}
          if #message == 0 then
            unet.driver.inter[id].routeAddr = tostring(addr)
            print("no conflicts found, address assigned")
            return true,tostring(addr)
          elseif message[3] == id and message[4] == "data0" 
            and message[5] == "ARP_REPLY" and message[5] == tostring(addr) then
            print("address is in use, retrying")
            break
          end
        end
      end
    end
  
  end
end

function unet.arp.scan(id,addr)
  if not id then
    id = unet.resolveID()
  end
  unet.driver.inter[id].ubroadcast("data0","ARP_REQUEST",pack.serialize({["dest"] = addr,
    ["source"] = unet.driver.inter[id].parent.."/"..unet.driver.inter[id].routeAddr}))
end

function unet.arp.linkParent(id)
  return false,"incomplete"
end

--arp aware send function for unet

function unet.send(address,flag,data)
  if unet.routes[address] then
    local route = unet.routes[address]
    unet.driver.inter[route.id].usend(route.hw,flag,pack.serialize({dest=address,
      source=unet.driver.inter[route.id].routeAddr,data=data}))
  end
end

local function onMessage(_,source,interface,port,flag,data)
  if port == "data0" then
    
    if flag == "ARP_REQUEST" then
      data = pack.unserialize(data)
      if unet.driver.inter[id].routeAddr ~= "0" and unet.driver.inter[id].routeAddr == data.dest then
        unet.driver.inter[id].usend(source,"data0","ARP_REPLY",unet.driver.inter[id].routeAddr)
      end
      if data.source ~= "0/0" then
        unet.arp.routes[data.source] = {["id"] = id,["hw"] = source}
      end
    elseif flag == "ARP_REPLY" and not unet.arp.routes[data] then
      unet.arp.routes[data] = {["id"] = id,["hw"] = source}
    end
    
  end
end

event.listen("unet_hw_message",onMessage)
