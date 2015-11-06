local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local pack = require("serialization")

local unet = {}

unet.info = {   --version info, used in preloading and version control DO NOT EDIT
["gateway"] = {["addr"] = "", ["id"] = 1}, ["inter"] = {},
["os_build"] = "OpenOS 1.5",
["version"] = "1.0.0 Beta",
["allowOutdated"] = false,
["mods"] = "/unet/mods",
["config"] = "/unet/config.cfg"
}

function saveConfig()
  local toSave = {["gateway"] = unet.info.gateway,["inter"] = {}}
  
  for k,v in pairs(unet.info.inter do
    if v.static then
      toSave.inter[k] = v
    end
  end
  
  local file = fs.open(unet.info.config,"w")
  file.write(pack.serialize(toSave))
  file.close()
end


function loadConfig()
  if not fs.exists(unet.info.config) then
    saveConfig()
  end
  
  local file = fs.open(unet.info.config)
  local toLoad = file.read(math.huge)
  file.close()
  
  unet.info.gateway = toLoad.gateway
  unet.info.inter = toLoad.inter
end


function unet.getName()
  if _DEVICENAME then 
    return _DEVICENAME 
  else return 
    string.sub(computer.address(),1,5).."..."
  end
end

function unet.compareAddr(addr,inter)
  
end

function unet.resolveID(addr)
  return unet.info.gateway.id
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

return unet
