MenuEntry = {}

function MenuEntry:Init()
    self.control = nil
end

function MenuEntry:CreateControl(parent)
    assert(false, "Abstract")
end

function MenuEntry:GetControl()
    return self.control
end

MakeClassOf(MenuEntry)
