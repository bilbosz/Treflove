--[[
Example:
---------------------------------------
Player = {}

function Player:GetColor()
    return self.color
end

function Player:Init(color)
    self.color = color
    print("Player " .. tostring(self.color))
end

MakeClass(Player)
---------------------------------------
ComputerPlayer = {}

function ComputerPlayer:GetDifficulty()
    return self.difficulty
end

function ComputerPlayer:Init(color, difficulty)
    Player.Init(self, color)
end

MakeClass(ComputerPlayer, Player)
---------------------------------------
HumanPlayer = {}
MakeClass(HumanPlayer, Player)


player1, player2 = HumanPlayer("red"), ComputerPlayer("blue", 1)
print(player2:GetColor())
print(player1:GetColor())
---------------------------------------
]]

local function CreateIndex(self, ...)
    local n = select("#", ...)
    local index = {}
    for i = n, 2, -1  do
        local base = select(i, ...)
        assert(type(base) == "table")
        table.merge(index, getmetatable(base).__index)
    end
    table.merge(index, self)
    return index
end

function MakeClass(...)
    local self = ...
    local objMt = {
        __index = CreateIndex(self, ...)
    }
    local mt = {
        __index = objMt.__index,
        __call = function(...)
            local obj = {}
            setmetatable(obj, objMt)
            if obj.Init then
                obj:Init(select(2, ...))
            end
            return obj
        end
    }
    setmetatable(self, mt)
    return self
end
