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
  hw_addr = "00000000-0000-0000-0000-000000000000",
  addr = 0x0000000000000001,
  subnet = 0xFFFFFFFFFFFFFFFE,
  state = true,
    
  send = isend
}
