--[[
Example:
Player = class("Player")

function Player:GetColor()
    return self.color
end

function Player:__init(color)
    self.color = color
    print("Player " .. tostring(self.color))
end

ComputerPlayer = class("ComputerPlayer", Player)

function ComputerPlayer:GetDifficulty()
    return self.difficulty
end

function ComputerPlayer:__init(color, difficulty)
    self.Player.__init(self, color)
end

HumanPlayer = class("HumanPlayer", Player)

player1, player2 = HumanPlayer("red"), ComputerPlayer("blue", 1)
print(player2:GetColor())
print(player1:GetColor())
]]
class = {}

setmetatable(class, {
    __call = function(...) -- ... are base classes
        local cls = {}

        local args = {...}
        cls.__name = args[2]
        assert(type(cls.__name) == "string")
        cls.__bases = {select(3, ...)}
        assert(type(cls.__bases) == "table")

        for _, v in ipairs(cls.__bases) do
            cls[v.__name] = v
        end

        setmetatable(cls, {
            __call = function(...) -- ... are constructor params
                local mt = {
                    __index = {}
                }
                for i = #cls.__bases, 1, -1 do
                    local baseClass = cls.__bases[i]
                    table.merge(mt.__index, baseClass)
                end
                table.merge(mt.__index, cls)

                local obj = {}
                setmetatable(obj, mt)
                if obj.__init then
                    obj:__init(select(2, ...))
                end
                return obj
            end
        })
        return cls
    end
})
