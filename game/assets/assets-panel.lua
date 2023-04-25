DropArea = {}

local function CreateDropAreaText(self)
    local areaW, areaH = self:GetSize()

    local text = Text(self, "Drop file here", Consts.FOREGROUND_COLOR)
    local textW, textH = text:GetSize()
    local textS = (areaW - 2 * Consts.PADDING) / textW
    text:SetScale(textS)
    text:SetPosition(areaW * 0.5 - textW * textS * 0.5, areaH * 0.5 - textH * textS * 0.5)
end

function DropArea:Init(parent, width, height)
    Rectangle.Init(self, parent, width, height, Consts.FOREGROUND_COLOR, true)
    FileSystemDropEventListener.Init(self, true)
    CreateDropAreaText(self)
    app.fileSystemDropEventManager:RegisterListener(self)
end

function DropArea:OnFileSystemDrop(_, _, path, isDir)
    app:Log(path)
end

function DropArea:Release()
    app.fileSystemDropEventManager:UnregisterListener(self)
end

MakeClassOf(DropArea, Rectangle, FileSystemDropEventListener)

AssetsPanel = {}

local function CreateDropArea(self)
    local w = self:GetSize() - 2 * Consts.PADDING
    self.dropArea = DropArea(self, w, w)
    self.dropArea:SetPosition(Consts.PADDING, Consts.PADDING)
end

function AssetsPanel:Init(gameScreen, width, height)
    Panel.Init(self, gameScreen:GetControl(), width, height)
    CreateDropArea(self)
end

function AssetsPanel:OnResize(w, h)
    Panel.OnResize(self, w, h)
end

function AssetsPanel:Release()
    self.dropArea:Release()
end

MakeClassOf(AssetsPanel, Panel)
