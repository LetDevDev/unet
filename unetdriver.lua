local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local serialization = require("serialization")
local unet = require("unet")

unet.driver = {}

unet.driver.inter = {}

--Version info for use in preloading and version control, as well as configs

unet.driver.info = {    
["osBuild"] = "OpenOS 1.5",
["version"] = "0.0.5 ALPHA",
["allowOutdated"] = false,
["config"] = "/unet/driver/config.cfg",
["mods"] = "/unet/driver/mods"
}

--[[translation data for ports
You can edit these, but unless all devices (including parent devices)
on a network use the same numbers DEVICES MAY NOT BE ABLE TO COMMUNICATE]]

unet.driver.ports = {
["data0"]=65400,
["data1"]=65401,
["data2"]=65402,
["data3"]=65403,
["data4"]=65404,
["data5"]=65405
}

function unet.driver.loadConfig()

  if fs.exists(unet.driver.info.config) then
  
    local file = fs.open(unet.driver.info.config,"r")
	
    unet.driver.inter = serialization.unserialize(file:read(math.huge) or "{}")
    file:close()
	
  end
  
end

function unet.driver.saveConfig()
  --if fs.exists(unet.driver.info.config) then
  
  local file = fs.open(unet.driver.info.config,"w")
  
  
  local toSave = {}
  
  --strip functions and the logical addr from the data to be saved
  
  for k,v in pairs(unet.driver.inter) do
    toSave[k] = v
	toSave[k].usend,toSave[k].ubroadcast,toSave[k].routeAddr = nil,nil,nil
  end
  
  file:write(serialization.serialize(toSave))
  
  file:close()
  --end
  
end

function unet.driver.getID(addr,create)

  for id,proxy in pairs(unet.driver.inter) do
  
    if proxy.hw_addr == addr then
      return id
	end
	
  end
  
  if not create then 
    return false, "No such inteface"
  elseif not component.type(addr) then
    error("attempt to create proxy for a device that is not attached",3)
  end
  
  --if the interface has never been attached to the system before
  
  local start,id = 1
  for i=start,#unet.driver.inter do --if there is a gap, fill it
    if unet.driver.inter[i] == nil then
	  id = i
	  break
	end
  end
  
  if not id then --if there was not a gap, add a new id
    id = #unet.driver.inter + 1
  end
  
  unet.driver.inter[id] = {["hw_addr"]=addr,["routeAddr"]="0",["parent"]="0",["parusr"]="",["parpass"]=""}
  unet.driver.saveConfig()
  return id
  
end

function unet.driver.getAddr(id)

  if type(id) == "string" then
    id = tonumber(string.sub(id,6,#id))
  end
  
  if unet.driver.inter[id] then
    return unet.driver.inter[id].hw_addr
  else
    return false,"No such inteface"
  end
  
end

function unet.driver.removeInterface(id)

  if unet.driver.inter[id] and unet.driver.inter[id].isAvailable then
    unet.driver.inter[id] = nil
    saveConfig()	
  end

end

--[[construct a very basic pair of functions that are cross interface
the pair of functions behave the same no mater what type of
interface we are using, to do this, the driver creates translation
data here, allowing the illusion that every transmission device behaves the same]]

local function constructProxyFunctions(id)

  local addr = unet.driver.getAddr(id)
  local ctype = component.type(addr)
  
  --linked cards are a special case. they use the modem driver.
  
  if ctype == "tunnel" then
    ctype = "modem"
  end
  
  --if a mod exists for the component, load it
  
  if fs.exists(unet.driver.info.mods.."/"..ctype..".lua") then
    local constructor = loadfile(unet.driver.info.mods.."/"..ctype..".lua")
	constructor("init",addr)
  end
  
end

--[[Here we handle the physical interfaces, since we want to be very
flexible, this is all done automatically in the background, meaning that
a new interface device can be ready for unet usage very quickly. for modems
this is instant, and modem ports are opened.]]

local function onDeviceChanged(task,addr,ctype)
  
  --again, linked cards are a special case
  if ctype == "tunnel" then
    ctype = "modem"
  end
  
  if task == "component_added" and fs.exists(unet.driver.info.mods.."/"..ctype..".lua") then
  
    local id = unet.driver.getID(addr,true)
	constructProxyFunctions(id)
    computer.pushSignal("unet_interface_added",id)
	
  elseif task == "component_removed" and fs.exists(unet.driver.info.mods.."/"..ctype..".lua") then
  
    local id = unet.driver.getID(addr)
	
    local constructor = loadfile(unet.driver.info.mods.."/"..ctype..".lua")
	constructor("disable",addr,ctype)
	
    computer.pushSignal("unet_interface_removed",id)
	
  end
  
end

unet.driver.loadConfig()

for file in fs.list(unet.driver.info.mods) do

  for i=1,#file do
  
    if string.sub(file,i,i) == "." then
	  file = string.sub(file,1,i-1)
	end
	
  end
  
  for addr in component.list(file,true) do
    onDeviceChanged("component_added",addr,file)
  end
  
end

if fs.exists(unet.driver.info.mods.."/modem.lua") then

  for addr in component.list("tunnel",true) do
    onDeviceChanged("component_added",addr,"tunnel")
  end
  
end

event.listen("component_added",onDeviceChanged)
event.listen("component_removed",onDeviceChanged)

return unet
