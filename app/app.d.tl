-- app/app.lua (still Lua; its Client and Server subclasses too). The global
-- `app` is the running Client or Server.

global interface App is Object
    backstack_manager: BackstackManager
    -- any: the persisted game state read from save.lua (table_utils.from_string).
    data: {any: any}
    defer_manager: DeferManager
    height: number
    is_client: boolean
    is_server: boolean
    keyboard_manager: KeyboardManager
    logger: Logger
    params: ArgParserResult
    root: Control
    update_event: Event -- triggered with (dt) every frame
    wheel_event: Event -- triggered with (x, y) wheel movement (client only)
    width: number
    _draw_aabbs: boolean
    _mark_for_quit: boolean
    _start_time: number
    _time: number
    -- Fields whose types later phases declare:
    -- P1/P2/P3: add asset_manager: AssetManager
    -- P1/P2/P3: add button_event_manager: ButtonEventManager
    -- P1/P2/P3: add connection_manager: ConnectionManager
    -- P1/P2/P3: add file_system_drop_event_manager: FileSystemDropEventManager
    -- P1/P2/P3: add notification_manager: NotificationManager
    -- P1/P2/P3: add options_manager: OptionsManager
    -- P1/P2/P3: add pointer_event_manager: PointerEventManager
    -- P1/P2/P3: add resize_manager: ResizeManager
    -- P1/P2/P3: add screen_manager: ScreenManager
    -- P1/P2/P3: add session: Session
    -- P1/P2/P3: add text_event_manager: TextEventManager

    load: function(self)
    register_love_callbacks: function(self)
    get_time: function(self): number
    quit: function(self)
    -- any: logs values of any type (each formatted with %s).
    log: function(self, ...: any)
    log_fun: function(self, ...: any) -- any: see log
    rescale_root: function(self)
end

global app: App

-- The LÖVE configuration table (love.conf's argument), kept by conf.lua.
global record LoveWindowConfig
    title: string
    icon: string
    resizable: boolean
    fullscreen: boolean
    display: number
    width: number
    height: number
    minwidth: number
    minheight: number
end

global record LoveConfig
    console: boolean
    window: LoveWindowConfig
end

global config: LoveConfig
