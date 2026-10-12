-- game/token/token.tlt: a token on a page (constructor:
-- `Token(data: TokenData, parent: Control)`).

-- A token of the persisted state (GameState.tokens), the model data of a
-- Token.
global record TokenData
    name: string
    diameter: number -- in meters
    position: {number} -- x, y in page meters
    avatar: string -- the path of the avatar image asset
    owners: {string} -- logins (absent from the Lua annotation; in save.lua)
end

global interface Token is Model, Control
    data: TokenData
    _diameter: number
    _clip: ClippingMask
    _image: Image
    _label: Text
    _selection: Circle -- the selection highlight
    _is_selected: boolean
    _drag_mouse_button: number
    _prev_drag_mouse_x: number
    _prev_drag_mouse_y: number
    -- On app.pointer_event_manager: consumes pointer events over the token.
    on_pointer_event: function(self, x: number, y: number, id: PointerId)
    get_radius: function(self): number
    set_select: function(self, value: boolean)
    get_select: function(self): boolean
end
