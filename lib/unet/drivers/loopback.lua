local event = require("event")
local unet = require("unet")

local isend = function(self,dest,proto,data)
  if not self.state then
    return false
  end
  event.push("unet_packet",self.addr,self.addr,proto,data)
  return true
end

unet.interfaces.lo0 = {
  hw_type = "software_loopback",
  addr = 0x0000000000000001,
  subnet = 0xFFFFFFFFFFFFFFFE,
  state = true,
    
  send = isend
}
