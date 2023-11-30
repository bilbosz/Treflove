local WaitingScreen = require("screens.waiting-screen")

---@class ConnectingScreen: WaitingScreen
local ConnectingScreen = class("ConnectingScreen", WaitingScreen)

function ConnectingScreen:init()
    WaitingScreen.init(self, "Connecting...")
end

return ConnectingScreen
