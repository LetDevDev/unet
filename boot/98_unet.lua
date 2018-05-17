local fs = require("filesystem")
local unet = require("unet")

unet.driver_path = "/lib/unet/drivers/"

for driver in fs.list(unet.driver_path) do
  dofile(unet.driver_path..driver)
end
