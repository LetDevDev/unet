local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local serialization = require("serialization")

local unet = {}

unet.info = {   --version info, used in preloading and version control DO NOT EDIT 
["os_build"] = "OpenOS 1.5",
["version"] = "0.0.5 ALPHA",
["allowOutdated"] = false,
["mods"] = "/unet/mods"
}

--because unet will try to use a var _DEVICENAME that may or may not exist
--this function checks to make sure that the var acutally exists, and 
--uses the computer addr as a replacement name if the var does not exist

function unet.getName()
  if _DEVICENAME then 
    return _DEVICENAME 
  else return 
    string.sub(computer.address(),1,5).."..."
  end
end

--usually called by other functions in other modules, this is used to determine
--the first available interface, and returns it's id.

function unet.resolveID()
  for i=1,#unet.driver.inter do
    if unet.driver.inter[i] and unet.driver.inter[i].isAvailable then 
	    return i
	  end
  end
  return false
end

--version checker and module loader, looks for a file with the argument as it's name
--then checks to see if it is already loaded, or if it has is valid for loading, ie
--built for this version of unet and this OS. it loads it and returns true, or an error
--message if it could not load.

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
