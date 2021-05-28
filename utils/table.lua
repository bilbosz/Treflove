function table.merge(self, other)
    for k, v in pairs(other) do
        self[k] = v
    end
    return self
end