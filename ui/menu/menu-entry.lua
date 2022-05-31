MenuEntry = {}

function MenuEntry:Init()
    self.control = nil
end

function MenuEntry:CreateControl(parent)
    abstract()
end

function MenuEntry:GetControl()
    return self.control
end

MakeClassOf(MenuEntry)
