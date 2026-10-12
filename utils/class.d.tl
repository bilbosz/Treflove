-- The class system (utils/class.tlt). Every class's instance type is a
-- global interface that is `Object` through its bases; the class table is
-- a variable typed by that same interface (docs/types.md, "Classes").

global interface Object
    -- `X(...)` constructs an X. any: constructor arguments are not checked
    -- at call sites (each class narrows `init` by assignment, which Teal
    -- does not carry over to `__call`; docs/types.md).
    metamethod __call: function(self, ...: any): self
    -- The constructor. any: each class assigns its own narrower function.
    init: function(self, ...: any)
    -- The destructor body: class() forwards `__destroy` to it, with the
    -- reason the object died (docs/lifetime.md).
    release: function(self, reason?: lifetime.Reason)
end

-- The reason an object died (lua-lifetime docs/02-semantics.md, "`__destroy`
-- and reasons"), for `release` definitions: a type name alone does not make
-- the transpiler bind the `lifetime` local in a file.
global type LifetimeReason = lifetime.Reason

-- class(name, base...): a new class table merging the bases' methods.
global class: function<T>(name: string, ...: Object): T
global get_class_of: function(obj: Object): Object
global get_class_name_of: function(obj: Object): string
global is_instance_of: function(obj: Object, cls: Object): boolean
-- any: asserts the type of a value of any type (a Lua type name or a class).
global assert_type: function(obj: any, typ: string | Object)
global assert_unreachable: function(msg?: string)
-- An implementation that raises, for an abstract method: `X.m = abstract()`.
global abstract: function<F>(): F
