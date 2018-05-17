local component = require("component")
local event = require("event")
local serial = require("serialization")
local unet = require("unet")

_modem_driver = {}

_modem_driver.resolve = function(interface, addr)
  for i = 1, #interface.arp_cache,1 do
    if interface.arp_cache[i][1] == addr then
      return true, interface.arp_cache[i][2]
    end
  end
  
  component.invoke(interface.hw_addr,"broadcast",interface.hw_channel,"arp_request",interface.addr,addr)
  
  success,_,mac = event.pull(5,"modem_message",interface.hw_addr,nil,interface.hw_channel,nil,"arp_reply",addr)
  
  if success ~= nil then
    table.insert(interface.arp_cache,{addr,mac})
    interface.arp_cache[interface.arp_cache.max_entries + 1] = nil
    return true, mac
  end
  
  return false
end

_modem_driver.isend = function(self,dest,proto,data)
  if not self.state then
    return false
  end
  if unet.utils.getBroadcastAddr(self) == dest then
    return component.invoke(self.hw_addr,"broadcast",self.hw_channel,"unet_packet",self.addr,dest,proto,data)
  else
    success,mac = resolve(self,dest)
    if success then
      return component.invoke(self.hw_addr,"send",mac,self.hw_channel,"unet_packet",self.addr,dest,proto,data)
    end
    return success
  end
end

_modem_driver.recieve = function(name,our_mac,their_mac,channel,distance,preamble,their_ip,our_ip,proto,data)
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

function _modem_driver.create(name,hw_addr,channel,cache,addr,subnet,dhcp)
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
    hw_addr = k,
    hw_channel = 2,
    arp_cache = {max_entries = 5},
    addr = 0x0000000000010000 + math.floor(math.random(1,0xFFFE)),
    dhcp = dhcp,
    subnet = subnet,
    state = true, 
    
    send = isend
  }
end

function _modem_driver.load()

end

function _modem_driver.save()

end

function _modem_driver.remove()

end

for k,v in pairs(modems) do
  if component.invoke(k,"isWireless")  then 
    component.invoke(k,"open",2)
    
    unet.interfaces["wifi"..component.slot(k)] = {
      
    }
  end
  if component.invoke(k,"isWired") then
    component.invoke(k,"open",1)
    
    unet.interfaces["eth"..component.slot(k)] = {
      hw_addr = k,
      hw_channel = 1,
      arp_cache = {max_entries = 5},
      addr = 0x0000000000010000 + math.floor(math.random(1,0xFFFE)),
      subnet = 0xFFFFFFFFFFFF0000,
      state = true,
      
      send = isend
    }
  end

  print("Registered modem: "..k)
   
end

