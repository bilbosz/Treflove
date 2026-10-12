-- utils/utils.tlt
global record Utils
    draw_aabbs: function(ctrl: Control)
    dump_controls: function(ctrl: Control, indent?: string): string
    monitor_object: function(obj: Object, black_functions?: {function})
    mix: function(a: number, b: number, x: number): number
    clamp: function(min: number, max: number, x: number): number
    generate_salt: function(len: integer): string
    hash: function(str: string): string
    get_time: function(): number
    get_stack_trace: function(min_level?: integer): string
    split_path: function(path: string): {string}
    error_handler: function(module: string): function(msg: string)
end
