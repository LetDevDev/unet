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

function unet.arp.assignAddress(id)
  if unet.driver.inter[id] and unet.driver.inter[id].isAvailable then
    
    if unet.driver.inter[id].parent == "0" then
      --print("getting address for unmanaged network on ",id)
      while true do
        math.randomseed(os.time())
        local addr = math.random(65535)
        --print("attempting to assign address ",addr," to interface ",id)
        unet.arp.scan(id,"0/"..addr)
        while true do
        --print("loop")
        local message = {event.pull(5,"unet_hw_message")}
          if #message == 0 then
            unet.driver.inter[id].routeAddr = tostring(addr)
            --print("no conflicts found, address assigned")
            return true,tostring(addr)
          elseif message[3] == id and message[4] == "data0" 
            and message[5] == "ARP_REPLY" and message[5] == tostring(addr) then
            --print("address is in use, retrying")
            break
          end
        end
      end
    end
  
  end
end

function unet.arp.getAddress(id)
  return unet.driver.inter[id].parent.."/"..unet.driver.inter[id].routeAddr
end

function unet.arp.compareAddr(id,addr)
  if addr == unet.arp.getAddress(id) then 
    return "match"
  elseif addr == unet.driver.inter[id].parent then
    return "parent"
  elseif string.sub(addr,1,#unet.driver.inter[id].parent) == unet.driver.inter[id].parent then
    return "subnet"
  else
    return "not"
  end
end

function unet.arp.scan(id,addr)
  if not id then
    id = unet.resolveID()
  end
  unet.driver.inter[id].ubroadcast("data0","ARP_REQUEST",pack.serialize({["dest"] = addr,
    ["source"] = unet.arp.getAddress()}))
    
  local data = {event.pull(5,"unet_hw_message",nil,id,"data0","ARP_REPLY",nil,addr)}
    if #data > 0 then
      unet.arp.routes[addr] = {["id"] = id, ["hw"] = data[2]}
      return true,data[2]
    else
      return false
    end
end

function unet.arp.linkParent(id)
  return false,"incomplete"
end

--arp aware send function for unet

function unet.send(address,port,flag,data)
  if unet.arp.routes[address] then
    local route = unet.arp.routes[address]
    unet.driver.inter[route.id].usend(route.hw,port,flag,pack.serialize({dest=address,
      source=unet.arp.getAddress(route.id),data=data}))
    return true
  else
    return false
  end
end

local function onMessage(_,source,id,port,flag,time,data)
  if port == "data0" then
    
    if flag == "ARP_REQUEST" then
      data = pack.unserialize(data)
      if unet.driver.inter[id].routeAddr ~= "0" and unet.arp.getAddress(id) == data.dest then
        unet.driver.inter[id].usend(source,"data0","ARP_REPLY",unet.arp.getAddress(id))
      end
      if data.source ~= "0/0" then
        unet.arp.routes[data.source] = {["id"] = id,["hw"] = source}
      end
    
  end
end

event.listen("unet_hw_message",onMessage)
