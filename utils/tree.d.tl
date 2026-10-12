-- utils/tree.tlt: a node with a parent and ordered children.
global interface Tree is Object
    parent: Tree
    children: {Tree}
    set_parent: function(self, parent: Tree)
    add_child: function(self, child: Tree)
    remove_child: function(self, child: Tree)
    get_children: function(self): {Tree}
    get_parent: function(self): Tree
    reattach: function(self, n?: integer)
end
