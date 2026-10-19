-- utils/media.tlt
-- A LÖVE object made from a media file: a love.Source, love.Image,
-- love.Font or love.Video (Teal cannot discriminate a union of several
-- interfaces, so the common supertype stands for it).
global type LoveMedium = love.Object

global record Media
    -- The kind of a media file; the value is also its display name.
    enum Type
        "VIDEO"
        "AUDIO"
        "IMAGE"
        "FONT"
        "TEXT"
    end
    get_type_and_medium: function(data: string): Media.Type, LoveMedium
end
