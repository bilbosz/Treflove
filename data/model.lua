Model = {}

function Model:Init(data)
    self.data = data
end

function Model:GetData()
    return self.data
end

MakeClassOf(Model)
