MenuEntry = {}

function MenuEntry:Init()

end

function MenuEntry:CreateControl(anchor)
    assert(false, "Abstract")
end

MakeClassOf(MenuEntry)
