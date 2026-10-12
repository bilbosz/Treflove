-- utils/aabb.tlt: an axis-aligned bounding box, stored as the array
-- {min_x, min_y, max_x, max_y}.
global interface Aabb is {number}, Object
    get_bounds: function(self): number, number, number, number
    get_position_and_size: function(self): number, number, number, number
    set_position_and_size: function(self, x: number, y: number, w: number, h: number)
    get_min_x: function(self): number
    get_min_y: function(self): number
    get_max_x: function(self): number
    get_max_y: function(self): number
    add_point: function(self, x: number, y: number)
    add_aabb: function(self, other: Aabb)
    set: function(self, other: Aabb)
    reset: function(self)
    is_point_inside: function(self, x: number, y: number): boolean
    get_width: function(self): number
    get_height: function(self): number
    is_intersecting: function(self, other: Aabb): boolean
    get_position: function(self): number, number
    get_size: function(self): number, number
    is_intersecting_circle: function(self, x: number, y: number, r: number): boolean
end
