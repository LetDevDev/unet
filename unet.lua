local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local pack = require("serialization")

local unet = {}

unet.info = {   --version info, used in preloading and version control DO NOT EDIT
["gateway"] = 1, ["inter"] = {},
["os_build"] = "OpenOS 1.5",
["version"] = "1.0.0 Beta",
["allowOutdated"] = false,
["mods"] = "/unet/mods",
["config"] = "/unet/config.cfg"
}

function saveConfig()
  local toSave = {["gateway"] = unet.info.gateway,["inter"] = unet.info.inter}
  
  for k,v in pairs(unet.info.inter) do
    if not v.static then
      toSave[k].addr = ""
    end
  end
  
  local file = fs.open(unet.info.config,"w")
  file.write(pack.serialize(toSave))
  file.close()
  computer.pushSignal("unet_config_saved")
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
  computer.pushSignal("unet_config_loaded")
end


function unet.getName()
  if _DEVICENAME then 
    return _DEVICENAME 
  else return 
    string.sub(computer.address(),1,5).."..."
  end
end

function unet.setGateway(id)
  if unet.driver.inter[id].isAvailible then
    unet.info.gateway = id
    unet.saveConfig()
    return true
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

function unet.transmit(dest,ttl,packetType,data,inter)
  if not inter then
    inter = unet.info.gateway
  end
  
end

return unet
