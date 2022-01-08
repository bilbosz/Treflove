ConnectionScreen = {}

function ConnectionScreen:Init()
    WaitingScreen.Init(self, "Connecting...")
end

MakeClassOf(ConnectionScreen, WaitingScreen)
