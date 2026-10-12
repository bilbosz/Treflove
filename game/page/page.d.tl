-- game/page/page.tlt: a page of the game world: its background
-- image and the tokens on it.

-- A page of the persisted state (GameState.pages), the model data of a
-- Page.
global record PageData
    name: string
    pixel_per_meter: number
    width: number -- the page width in meters
    image: string -- the path of the background image asset
    tokens: {string} -- the names of the tokens on the page
end

global interface Page is Model, ClippingRectangle
    data: PageData
    _background: Image
    _page_coordinates: Control -- the coordinate system scaled to page meters
    _name: string
    _pixel_per_meter: number
    _page_width: number
    _pointer_down_pos: {PointerId: {number}} -- the local pointer-down position per button
    _game_screen: GameScreen
    _selection: Selection
    _tokens: {Token}
    _select_set_start_pos: {Token: {number}} -- while dragging tokens
    _create_background: function(self, path: string)
    _create_page_coordinates: function(self)
    get_page_coordinates: function(self): Control
    get_tokens: function(self): {Token}
    -- On app.pointer_event_manager (the id is never nil for down and up).
    on_pointer_down: function(self, x: number, y: number, button: PointerId)
    on_pointer_up: function(self, x: number, y: number, button: PointerId)
    on_pointer_move: function(self, x: number, y: number)
    on_wheel_moved: function(self, x: number, y: number) -- on app.wheel_event
    get_game_screen: function(self): GameScreen
    get_selection: function(self): Selection
end
