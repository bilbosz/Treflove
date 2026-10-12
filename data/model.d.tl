-- data/model.tlt
-- any: model data is the dynamically shaped game state that is persisted
-- to save.lua and sent over the network; its values are of every type.
global type ModelData = {string | number: any}

global interface Model is Object
    data: ModelData
    get_data: function(self): ModelData
    -- any: see ModelData.
    set_data: function(self, key: string | number, value: any)
end
