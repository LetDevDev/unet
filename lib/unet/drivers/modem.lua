local component = require("component")
local event = require("event")
local serial = require("serialization")
local unet = require("unet")

modem_driver = {}

--[[ Arp resolution, given a Unet interface, will dicover the target node
interface: the unet interface to use for resolution
addr: the unet address to resolve
returns true and a mac address on success, false and a error string on failure
]]
modem_driver.resolve = function(interface, addr)
  if not interface.hw_type == "modem" then
    return false, "interface not a modem"
  end
  
  for i = 1, #interface.arp_cache do  --First check to see if the arp cache has it
    if interface.arp_cache[i][1] == addr then
      return true, interface.arp_cache[i][2]
    end
  end
  
  component.invoke(interface.hw_addr,"broadcast",interface.hw_channel,"arp_request",addr)
  
  success,_,mac = event.pull(5,"modem_message",interface.hw_addr,nil,interface.hw_channel,nil,"arp_reply",addr)
  
  if success ~= nil then
    table.insert(interface.arp_cache,{addr,mac})
    interface.arp_cache[interface.arp_cache.max_entries + 1] = nil
    return true, mac
  end
  
  return false, "no device found"
end


--[[ Interface send, unet wrapper object to transmit a packet using a modem
self: the unet interface to use for transmission
dest: the unet address to send too
proto: the unet header to attach, see documentation
returns a boolean representing success
]]
modem_driver.isend = function(self,dest,proto,data)
  if not self.state then  --If the interface is down, do not send
    return false
  end
  if unet.utils.getBroadcastAddr(self) == dest then --if the target is this network's broadcast, perform hardware broadcast
    return component.invoke(self.hw_addr,"broadcast",self.hw_channel,"unet_packet",self.addr,dest,proto,data)
  else
    success,mac = resolve(self,dest)
    if success then
      return component.invoke(self.hw_addr,"send",mac,self.hw_channel,"unet_packet",self.addr,dest,proto,data)
    end
    return success
  end
end

--Driver receive event listener, not for application use.
modem_driver.recieve = function(name,our_mac,their_mac,channel,distance,preamble,their_ip,our_ip,proto,data)
  if preamble == "unet_packet" then
    for k,v in pairs(unet.interfaces) do
      if v.hw_addr == our_mac and (v.addr == our_ip or unet.utils.getBroadcastAddr(v) == our_ip) then
        event.push("unet_packet",our_ip,their_ip,proto,data)
      end
    end
  elseif preamble == "arp_request" then
    for k,v in pairs(unet.interfaces) do
      if v.hw_addr == our_mac and v.addr == our_ip then
        component.invoke(v.hw_addr,"send",their_mac,channel,"arp_reply",v.addr)
      end
    end
  end
end

event.listen("modem_message",recieve)

--[[create the wrapper for a new interface
name: the name to use for the interface
hw_addr: the address to use for the interface
channel: the hw channel to use for transmission, useful for vlan's
addr: the address to start the interface with
subnet: the subnet mask to start the interface with
dhcp: whether or not the interface will automatically handle addressing
for changes to persist, save should be called
]]
function modem_driver.create(name,hw_addr,channel,cache,addr,subnet,dhcp)
  if not component.slot(hw_addr) then
    return false, "no such component"
  end
  
  if not component.invoke(hw_addr,"open",channel) then
    return false, "no avalable ports"
  end
  
  if unet.interfaces[name] then
    return false, "interface with name exists"
  end
  
  unet.interfaces[name] = {
    hw_type = "modem",
    hw_addr = hw_addr,
    hw_channel = channel,
    arp_cache = {max_entries = cache},
    addr = addr,
    dhcp = dhcp,
    subnet = subnet,
    state = true, 
    
    send = isend
  }
  
  return true
end

--Called at startup, loads all the modem interfaces into memory and starts them
function modem_driver.load()
  dofile("/etc/unet/drivers/modems.cfg")
end

--Called when it's time to commit changes to the drive
function modem_driver.save()
  local modems = {}
  for k,v in pairs(unet.interfaces) do
    if hw_type and hw_type == "modem" then
      modems[k] = v
      modems[k].arp_cache = {max_entries = v.arp_cache.max_entries} --Purge arp entries
      if v.dhcp then  --if the address is dhcp, then it is configured at load time
        modems[k].address = 0
        modems[k].subnet = 0
      end
      send = nil
    end
  end
  --[[io.open("/etc/unet/drivers/modems.cfg")   --To be properly written later
    io.write(serial.serialize(unet.interfaces = modems))
  io.close()]]
end

--[[Remove a wrapper from the loaded interfaces and release the hw port
name: the interface to remove
For changes to persist, save should be called
]]
function modem_driver.remove(name)
  if unet.interfaces[name] then
    component.invoke(unet.interfaces[name].hw_addr,"close",unet.interfaces[name].hw_channel)
    unet.interfaces[name] = nil
  end
end

