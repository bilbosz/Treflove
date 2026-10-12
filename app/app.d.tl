-- app/app.tlt: the base of Client (app/client.d.tl) and
-- Server (app/server.d.tl). The global `app` is the running one.

global interface App is Object
    asset_manager: AssetManager
    backstack_manager: BackstackManager -- client only
    button_event_manager: ButtonEventManager -- client only
    connection_manager: ConnectionManager
    -- The persisted game state (server/save.lua): the server reads it at
    -- load, the client receives it with GameDataRp; nil before that.
    data: GameState
    defer_manager: DeferManager
    file_system_drop_event_manager: FileSystemDropEventManager -- client only
    height: number
    is_client: boolean
    is_server: boolean
    keyboard_manager: KeyboardManager -- client only
    logger: Logger
    notification_manager: NotificationManager -- client only
    options_manager: OptionsManager -- client only
    params: ArgParserResult
    pointer_event_manager: PointerEventManager -- client only
    resize_manager: ResizeManager -- client only
    root: Control -- nil without a window (headless server)
    screen_manager: ScreenManager -- nil on a headless server
    session: Session -- client only: the session of its one connection
    text_event_manager: TextEventManager -- client only
    update_event: Event -- triggered with (dt) every frame
    wheel_event: Event -- triggered with (x, y) wheel movement (client only)
    width: number
    _draw_aabbs: boolean
    _mark_for_quit: boolean
    _start_time: number
    _time: number

    load: function(self) -- abstract: implemented by Client and Server
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
