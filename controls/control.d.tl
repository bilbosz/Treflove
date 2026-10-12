-- controls/control.tlt: the base of every UI element. The
-- control tree is not an ownership tree (docs/lifetime.md, "Ownership").
global interface Control is Tree
    parent: Control
    children: {Control}
    global_transform: love.Transform -- protected
    size: {number, number} -- protected: width, height
    _global_aabb: Aabb -- the AABB of the control and its enabled descendants
    _is_enabled: boolean
    _is_visable: boolean -- sic: the Lua spells it so
    _local_transform: love.Transform
    _origin: {number, number}
    _position: {number, number}
    _rotation: number
    _scale: {number, number}

    _update_local_transform: function(self)
    _update_global_transform: function(self)
    _update_global_aabb_children: function(self)
    _update_global_aabb_parent: function(self)
    _update_global_aabb: function(self)
    _update_transform: function(self)
    _reset_local_transform: function(self)
    _get_recursive_aabb_detail: function(self, reference_transform: love.Transform): Aabb

    transform_to_local: function(self, x: number, y: number): number, number
    transform_to_global: function(self, x: number, y: number): number, number
    set_position: function(self, x?: number, y?: number)
    get_position: function(self): number, number
    set_scale: function(self, scale_x: number, scale_y?: number)
    get_scale: function(self): number, number
    set_rotation: function(self, rotation: number)
    get_rotation: function(self): number
    set_origin: function(self, x?: number, y?: number)
    get_origin: function(self): number, number
    add_child: function(self, child: Control)
    get_parent: function(self): Control
    get_children: function(self): {Control}
    get_position_and_size: function(self): number, number, number, number
    get_position_and_outer_size: function(self): number, number, number, number
    get_aabb: function(self): Aabb
    get_global_aabb: function(self): Aabb
    get_recursive_aabb: function(self, ctrl?: Control): Aabb
    get_global_recursive_aabb: function(self): Aabb
    set_size: function(self, width: number, height: number)
    get_size: function(self): number, number
    get_outer_size: function(self): number, number
    set_enabled: function(self, value: boolean)
    is_enabled: function(self): boolean
    are_all_predecessors_enabled: function(self): boolean
    set_visible: function(self, value: boolean)
    is_visible: function(self): boolean
    draw: function(self)
end
