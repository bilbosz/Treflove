MountPointSelector = {}

function MountPointSelector:Init(parent, width, height)
    Rectangle.Init(self, parent, width, height)
end

MakeClassOf(MountPointSelector, Rectangle)
