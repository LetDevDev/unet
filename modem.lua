local tArgs = {...}

local component = require("component")
local computer = require("computer")
local event = require("event")
local os = require("os")
unet = require("unet")

local version,osBuild = "0.0.5 ALPHA","OpenOS 1.5"

if version ~= unet.driver.info.version and not unet.driver.info.allowOutdated then
  error("Version mismatch: refer to documentation",3)
elseif osBuild ~= unet.driver.info.osBuild then
  error("OS mismatch: refer to documentation",3)
end

--print("modem mod loaded")
--print(tArgs[1].." "..tArgs[2])

if tArgs[1] == "init" and component.type(tArgs[2]) == "modem" then
  local id = unet.driver.getID(tArgs[2])
  
  for k,v in pairs(unet.driver.ports) do
    component.invoke(unet.driver.inter[id].hw_addr,"open",v)
  end

  unet.driver.inter[id].usend = function(dest,port,flag,data)
  
    if not unet.driver.inter[id].isAvailable then
      return false,"Interface is not avalible"
    elseif type(flag) ~= "string" or #flag > 128 then
      error("Malformed Flag: refer to documentation",3)
    elseif type(data) ~= "string" or #data > 4096 then
      error("Malformed Packet: refer to documentation",3)
    end
	
    local nport
	
    for k,v in pairs(unet.driver.ports) do
      if k == port then
        nport = v
        break
      end
    end
	
    if not nport then
      error("Bad argument: 2, no such port",3)
    end
	
    if component.invoke(unet.driver.inter[id].hw_addr,"send",dest,nport,flag,data,os.date()) then
      unet.driver.inter[id].tx.packets = unet.driver.inter[id].tx.packets + 1
      unet.driver.inter[id].tx.bytes = unet.driver.inter[id].tx.bytes + #flag + #data + #os.date()
	  return true
	end
    
  end
  
  unet.driver.inter[id].ubroadcast = function(port,flag,data)
  
    if not unet.driver.inter[id].isAvailable then
      return false,"Interface is not avalible"
    elseif type(flag) ~= "string" or #flag > 128 then
      error("Malformed Flag: refer to documentation",3)
    elseif type(data) ~= "string" or #data > 4096 then
      error("Malformed Packet: refer to documentation",3)
    end
	
    local nport

    for k,v in pairs(unet.driver.ports) do
      if k == port then
        nport = v
        break
      end
    end
	
    if not nport then
      error("Bad argument: 2, no such port",3)
    end
	
    if component.invoke(unet.driver.inter[id].hw_addr,"broadcast",nport,flag,data,os.date()) then
      unet.driver.inter[id].tx.packets = unet.driver.inter[id].tx.packets + 1
      unet.driver.inter[id].tx.bytes = unet.driver.inter[id].tx.bytes + #flag + #data + #os.date()
	  return true
	end
	
  end
    
  unet.driver.inter[id].isAvailable = true
  
  unet.driver.inter[id].routeAddr = "0"
  
  unet.driver.inter[id].tx = {["packets"]=0,["bytes"]=0}
  unet.driver.inter[id].rx = {["packets"]=0,["bytes"]=0}
  
end

if tArgs[1] == "init" and component.type(tArgs[2]) == "tunnel" then
  local id = unet.driver.getID(tArgs[2])
  
  unet.driver.inter[id].usend = function(dest,port,flag,data)
  
    if not unet.driver.inter[id].isAvailable then
      return false,"Interface is not avalible"
    elseif type(flag) ~= "string" or #flag > 128 then
      error("Malformed Flag: refer to documentation",3)
    elseif type(data) ~= "string" or #data > 4096 then
      error("Malformed Packet: refer to documentation",3)
	elseif not unet.driver.ports[port] then
	  error("Bad argument: 2, no such port",3)
    end
    
    if component.invoke(unet.driver.inter[id].hw_addr,"send",flag,data,os.date(),port) then
      unet.driver.inter[id].tx.packets = unet.driver.inter[id].tx.packets + 1
      unet.driver.inter[id].tx.bytes = unet.driver.inter[id].tx.bytes + #flag + #data + #os.date()
	  return true
	end
    
  end
  
  unet.driver.inter[id].ubroadcast = function(port,flag,data)
  
    if not unet.driver.inter[id].isAvailable then
      return false,"Interface is not avalible"
    elseif type(flag) ~= "string" or #flag > 128 then
      error("Malformed Flag: refer to documentation",3)
    elseif type(data) ~= "string" or #data > 4096 then
      error("Malformed Packet: refer to documentation",3)
    elseif not unet.driver.ports[port] then
      error("Bad argument: 2, no such port",3)
    end
	
	if component.invoke(unet.driver.inter[id].hw_addr,"send",flag,data,os.date(),port) then
      unet.driver.inter[id].tx.packets = unet.driver.inter[id].tx.packets + 1
      unet.driver.inter[id].tx.bytes = unet.driver.inter[id].tx.bytes + #flag + #data + #os.date()
	  return true
	end
	
  end
  
  unet.driver.inter[id].isAvailable = true
  
  unet.driver.inter[id].routeAddr = "0"
  
  unet.driver.inter[id].tx = {["packets"]=0,["bytes"]=0}
  unet.driver.inter[id].rx = {["packets"]=0,["bytes"]=0}
end

--print(tArgs[1] == "disable")
--print(component.type(tArgs[2]))

if tArgs[1] == "disable" and tArgs[3] == "modem" or tArgs[3] == "tunnel" then
  
  --print("disabling")
  
  local id = unet.driver.getID(tArgs[2])
  
  unet.driver.inter[id].usend = nil
  unet.driver.inter[id].ubroadcast = nil
  unet.driver.inter[id].isAvailable = false
  
end

local old = {{},{},{},{},{}}
local limit = 5

local function areMatching(tData)
  
  for i=1,limit do
    for j=1,#old[i] do
	  if old[i][j] ~= tData[j] then
	    --print(i.." : "..j.." No Match")
	    break
	  elseif j == #old[i] and j == #tData then
	    --print("match")
	    return true
	  end
	end
  end
  
end

local function onModemMessage(...)
  local tArgs = {...}
  local port
  
  --print("message")
  
  local matching
  
  if areMatching(tArgs) then return end
  
  table.insert(old,tArgs)
  if #old > limit then
    table.remove(old,1)
  end
  
  if tArgs[4] == 0 and unet.driver.ports[tArgs[9]] then
    port = tArgs[9]
  end
  
  for k,v in pairs(unet.driver.ports) do
    if tArgs[4] == v then port = k end
  end

  if not port then return end
  local id = unet.driver.getID(tArgs[2])
  
  if not id then return end
  
  unet.driver.inter[id].rx.packets = unet.driver.inter[id].rx.packets + 1
  unet.driver.inter[id].rx.bytes = unet.driver.inter[id].rx.bytes + (#tArgs[6] + #tArgs[7] + #tArgs[8])
  
  computer.pushSignal("unet_hw_message",tArgs[3],id,port,tArgs[6],tArgs[8],tArgs[7])
end

event.listen("modem_message",onModemMessage)
