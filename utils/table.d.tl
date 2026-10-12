-- Table utilities (utils/table.tlt): the module `table_utils`, plus the
-- global iterators and `toboolean`. Every walk skips the lifetime
-- runtime's state record (`lifetime.is_state`), which a table the runtime
-- has seen carries in one extra field.

global record TableUtils
    is_identifier: function(str: string): boolean
    merge: function<K, V>(destination: {K: V}, source: {K: V})
    merge_array: function<V>(destination: {V}, source: {V})
    copy: function<K, V>(source: {K: V}): {K: V}
    deep_copy: function<K, V>(source: {K: V}): {K: V}
    -- any: serializes values of any type (those it cannot write are skipped).
    to_string: function(source: any): string
    -- any: the table read back holds whatever was serialized.
    from_string: function(str: string): {any: any}
    find_table_key: function<K, V>(tab: {K: V}, value: V): K
    find_array_idx: function<V>(array: {V}, value: V): integer
    is_empty: function<K, V>(tab: {K: V}): boolean
end

-- The step function of `ripairs`: the previous index and value.
global prev: function<V>(t: {V}, i: integer): integer, V
global ripairs: function<V>(t: {V}): (function({V}, integer): (integer, V), {V}, integer)
-- Iterators over a copy, so the loop body may modify the table.
global cpairs: function<K, V>(t: {K: V}): (function({K: V}, K): (K, V), {K: V}, K)
global cipairs: function<V>(t: {V}): (function({V}, integer): (integer, V), {V}, integer)
global cripairs: function<V>(t: {V}): (function({V}, integer): (integer, V), {V}, integer)
-- any: converts a value of any type to its truth value.
global toboolean: function(value: any): boolean
