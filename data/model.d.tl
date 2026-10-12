-- data/model.tlt
-- any: model data is the dynamically shaped game state that is persisted
-- to save.lua and sent over the network; its values are of every type.
-- The keys are strings, so that a subclass may narrow `data` to a record
-- of its own (Token's TokenData): Teal takes a record for a subtype of
-- `{string: any}`, not of `{string | number: any}`.
global type ModelData = {string: any}

global interface Model is Object
    -- ModelData, spelled out: a field narrowed to a record in a subclass
    -- is checked against an alias as against a nominal type, and fails.
    data: {string: any} -- any: see ModelData
    get_data: function(self): ModelData
    -- any: see ModelData.
    set_data: function(self, key: string, value: any)
end
