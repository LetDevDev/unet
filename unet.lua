local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local serialization = require("serialization")

local unet = {}
unet.comm = {}

unet.info = {   --version info, used in preloading and version control DO NOT EDIT 
["os_build"] = "OpenOS 1.5",
["version"] = "0.0.4 ALPHA",
["allowOutdated"] = false,
["mods"] = "/unet/mods"
}

--because unet will try to use a var _DEVICENAME that may or may not exist
--this function checks to make sure that the var acutally exists, and 
--uses the computer addr as a replacement name if the var does not exist

function unet.getName()
  if _DEVICENAME then return _DEVICENAME 
  else return string.sub(computer.address(),1,5).."..."
  end
end

function unet.resolveID()
  for for i=1,#unet.driver.inter do
    if unet.driver.inter[i] and unet.driver.inter[i].isAvailable then 
	  return i
	end
  end
  return false
end

function unet.loadMod(name)
  if unet[name] then
    return true,"Mod already loaded into memory"
  elseif fs.exists(unet.info.mods.."/"..name..".lua") then
    dofile(unet.info.mods.."/"..name..".lua")
	if unet[name] then
	  return true,"Mod loaded into unet"
	else
	  return false,"Mod failed to load"
	end
  end
end

--a basic function that sends a message to parent devices requesting more
--information about them, this also signals the start of functions that
--a user will actually use normally

--[[function unet.comm.scanForParent(faddr,id)
  if not id then id = resolveID() end
  if id = false or not unet.driver.inter[id].isAvailable then
    return false, "Device not found"
  end
  if faddr then
    unet.driver.inter[id].usend(faddr,"data0","UNET_PARENT_SCAN",unet.getName())
	return true
  else
    unet.driver.inter[id].ubroadcast("data0","UNET_PARENT_SCAN",unet.getName())
	return true
  end
end]]

--does what you'd expect, tries to connect to a parent device. the actual
--connection is automatic, if the connection is approved by the parent
--the device will connect automatically, an event is pushed when a response
--to this occures regardless

function unet.comm.connectToParent(id,addr,pass,user)
  if not unet.driver.inter[id].isAvailable then
    return false, "Device not found"
  end
  local data = serialization.serialize({["name"]=unet.getName(),["pass"]=pass or "",["user"]=user or ""})
  unet.driver.inter[id].usend(addr,"data0","UNET_PARENT_CONN_REQUEST",data)
  unet.driver.inter[id].parent = addr
  unet.driver.inter[id].pass = pass or ""
  unet.driver.inter[id].user = user or ""
  return true
end

return unet