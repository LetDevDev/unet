local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local serialization = require("serialization")
local unet = require("unet")

unet.direct = {}

unet.direct.info = {
os_build = "OpenOS 1.5",
build = "0.0.2 ALPHA",
version = "0.0.4 ALPHA",
config = "/unet/direct/config.cfg",
pairs = "/unet/direct/pairs.cfg",
mods = "/unet/direct/mods",
}

--config stuff

function unet.direct.loadConfig()

  if fs.exists(unet.direct.info.config) and fs.exists(unet.direct.info.pairs)then
  
    local file = fs.open(unet.direct.info.config,"r")
	
    unet.direct.settings = serialization.unserialize(file:read(math.huge))
    file:close()
	
	file = fs.open(unet.direct.info.pairs,"r")
    unet.direct.pairs = serialization.unserialize(file:read(math.huge))
	file:close()
	
  else
    unet.direct.settings = {["visible"] = true,["type"] = "pc"}
	unet.direct.pairs = {}
	unet.direct.saveConfig()
  end
  
end

function unet.direct.saveConfig()
  local file = fs.open(unet.direct.info.config,"w")
  file:write(serialization.serialize(unet.direct.settings))
  file:close()
  file = fs.open(unet.direct.info.pairs,"w")
  local toSave = {}
  for k,v in pairs(unet.direct.pairs) do
    v.send = nil
	toSave[k] = v
  end
  file:write(serialization.serialize(unet.direct.pairs) or {})
  file:close()
end



function unet.direct.scan(faddr,id)
  if not id then id = unet.resolveID() end
  if faddr then 
    unet.driver.inter[id].usend(faddr,"data0","UDIRECT_SCAN",unet.getName())
  else
    unet.driver.inter[id].ubroadcast("data0","UDIRECT_SCAN",unet.getName())
  end
end

function unet.direct.pair(name,addr,id)
  if not id then id = unet.resolveID() end
    unet.driver.inter[id]
end

--constructors

local function constructReply(name,id)
  local function reply(response)
    if response == "accept" then
	
	  unet.driver.inter[id].usend(unet.direct.pairs[name].hw_addr,"data0","UDIRECT_PAIRING_ACCEPTED",unet.getName())
	  unet.direct.pairs[name].status = "paired"
	  
	  
	elseif response == "reject" then
	
	  unet.driver.inter[id].usend(unet.direct.pairs[name].hw_addr,"data0","UDIRECT_PAIRING_REJECTED",unet.getName())
	  unet.direct.pairs[name] = nil
	  return true
	  
	end
  end
end

local function constructSend(id)
  
end

--event handling

local function onMessage(...)
  local tArgs = {...}

  if tArgs[5] == "UDIRECT_SCAN" and unet.direct.settings.visible then
    unet.driver.inter[tArgs[3]].usend(tArgs[2],"data0","UDIRECT_SCAN_REPLY",serialization.serialize({["name"]=unet.getName(),["type"]=unet.direct.settings.type,["protoversion"]=}))
  elseif tArgs[5] == "UDIRECT_SCAN_REPLY" then
    local name,dType = table.unpack(serialization.unserialize(tArgs[7]))
    computer.pushSignal("udirect_device_found",name,dType,tArgs[6],tArgs[2])
	
  elseif tArgs[5] == "UDIRECT_PAIR_REQUEST" then
    local name,dType = table.unpack(serialization.unserialize(tArgs[7]))
	
	if not unet.direct.pairs[name] and not unet.direct.pairs[name].hw_addr == tArgs[2] then
	  --constructor for paired object entry
	  unet.direct.pairs[name] = {["hw_addr"]=tArgs[2],["type"]=dType,["status"]="inbound_request",["inter"]=id,["reply"] = constructReply(name,id)}
	  computer.pushSignal("udirect_pairing_request",name,dType,tArgs[6],tArgs[2])
	end
	
  end
  
end

unet.direct.loadConfig()
event.listen("unet_hw_message",onMessage)