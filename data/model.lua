Model = {}

function Model:Init(data)
    self.data = data
end

function Model:GetData()
    return self.data
end

function Model:SetData(key, value)
    self.data[key] = value
end

MakeClassOf(Model)
