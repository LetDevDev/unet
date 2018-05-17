--Unet V2 Library, the core API.

local event = require("event")
unet = {interfaces = {}}


unet.utils = {
  isSameSubnet = function(first,second,mask)
    return (first & mask) == (second & mask)
  end,
  getBroadcastAddr = function(interface)
    return (~interface.subnet) | interface.addr
  end
}

unet.send = function(source,dest,proto,data)
  if type(proto) == "string" and data == nil then 
    data = proto
    proto = dest
    dest = source
    
    for k,v in pairs(unet.interfaces) do
      if v.addr == dest then
        event.push("unet_packet",dest,dest,proto,data)
      elseif unet.utils.isSameSubnet(v.addr,dest,v.subnet) then
        return v:send(dest,proto,data)
      end
    end
    
  else
  
    for k,v in pairs(unet.interfaces) do
      if v.addr == source then
        return v:send(dest,proto,data)
      end
    end
    
  end
end

return unet
