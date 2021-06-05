--[[
Example:
Player = class("Player")

function Player:GetColor()
    return self.color
end

function Player:Init(color)
    self.color = color
    print("Player " .. tostring(self.color))
end

ComputerPlayer = class("ComputerPlayer", Player)

function ComputerPlayer:GetDifficulty()
    return self.difficulty
end

function ComputerPlayer:Init(color, difficulty)
    Player.Init(self, color)
end

HumanPlayer = class("HumanPlayer", Player)

player1, player2 = HumanPlayer("red"), ComputerPlayer("blue", 1)
print(player2:GetColor())
print(player1:GetColor())
]]
class = {}

local function populateOrder(cls, order)
    local bases = cls.__bases
    for i = #bases, 1, -1 do
        local v = bases[i]
        populateOrder(v, order)
    end
    table.insert(order, cls)
end

setmetatable(class, {
    __call = function(...) -- ... are base classes
        local cls = {}

        local args = {...}
        cls.__name = args[2]
        assert(type(cls.__name) == "string")
        cls.__bases = {select(3, ...)}
        assert(type(cls.__bases) == "table")

        local mt = {
            __index = {}
        }

        local order = {}
        populateOrder(cls, order)
        for _, v in ipairs(order) do
            table.merge(mt.__index, v)
        end

        setmetatable(cls, {
            __call = function(...) -- ... are constructor params
                local obj = {}

                table.merge(mt.__index, cls)
                setmetatable(obj, mt)
                if obj.Init then
                    obj:Init(select(2, ...))
                end
                return obj
            end
        })
        return cls
    end
})
