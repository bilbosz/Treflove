local WaitingScreen = require("screens.waiting-screen")

---@class ConnectingScreen: WaitingScreen
local ConnectingScreen = class("ConnectingScreen", WaitingScreen)

---@return void
function ConnectingScreen:init()
    WaitingScreen.init(self, "Connecting...")
end

return ConnectingScreen
