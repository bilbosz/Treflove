AssetsPanel = {}

DropArea = {}

function DropArea:Init(parent)
    app.fileDropEventManager:Register(self)
end

function DropArea:Release()
    app.fileDropEventManager:Unregister(self)
end

MakeClassOf(DropArea, Rectangle, FileDropEventListener)

local function CreateDropArea(self)
    local areaW = self:GetSize() - 2 * Consts.PADDING
    local area = Rectangle(self, areaW, areaW, Consts.FOREGROUND_COLOR, true)
    self.dropArea = area

    area:SetPosition(Consts.PADDING, Consts.PADDING)

    local text = Text(area, "Drop File Here")
    local textW, textH = text:GetSize()
    local textS = (areaW - 2 * Consts.PADDING) / textW
    text:SetScale(textS)
    text:SetPosition(areaW * 0.5 - textW * textS * 0.5, areaW * 0.5 - textH * textS * 0.5)
end

function AssetsPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    CreateDropArea(self)
end

function AssetsPanel:OnResize(w, h)
    Panel.OnResize(self, w, h)
end

MakeClassOf(AssetsPanel, Panel)
