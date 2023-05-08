PreviewArea = {}

local function CreateDropAreaText(self)
    local areaW, areaH = self:GetSize()

    local text = Text(self, "Preview", Consts.FOREGROUND_COLOR)
    local textW, textH = text:GetSize()
    local textS = (areaW - 2 * Consts.PADDING) / textW
    text:SetScale(textS)
    text:SetPosition(areaW * 0.5 - textW * textS * 0.5, areaH * 0.5 - textH * textS * 0.5)
end

function PreviewArea:Init(parent, width, height)
    Rectangle.Init(self, parent, width, height, Consts.FOREGROUND_COLOR, true)
    FileSystemDropEventListener.Init(self, true)
    CreateDropAreaText(self)
    app.fileSystemDropEventManager:RegisterListener(self)
end

function PreviewArea:OnFileSystemDrop(x, y, file)
    local ok, err = file:open("r")
    assert(ok, err)
    self.parent:SetFile(file)
    self.parent:SetFileType(file)
    file:close()
end

function PreviewArea:Release()
    app.fileSystemDropEventManager:UnregisterListener(self)
end

MakeClassOf(PreviewArea, Rectangle, FileSystemDropEventListener)