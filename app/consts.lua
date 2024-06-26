---@class Consts
local Consts = {
    APP_USAGE_MESSAGE = [[
Usage:
    treflun <app_type> <address> <port>
]],
    APP_SUCCESS_EXIT_CODE = 0,
    NETWORK_COMPRESSION = "lz4",
    HASH_ALGORITHM = "sha256",
    ASSETS_SERVER_ROOT = "s",
    ASSETS_CLIENT_ROOT = "c",
    CLIENT_SEED = 6280149384430876,
    SERVER_SEED = 6931810848561579,
    MODEL_WIDTH = 2000,
    BACKGROUND_COLOR = {
        0.45,
        0.5,
        0.5
    },
    FOREGROUND_COLOR = {
        0.8,
        0.85,
        0.9
    },
    BUTTON_NORMAL_COLOR = {
        0.8,
        0.8,
        0.8
    },
    BUTTON_MULTIVALUE_NORMAL_COLOR = {
        0.8,
        0.8,
        0.7
    },
    BUTTON_HOVER_COLOR = {
        0.9,
        0.9,
        0.9
    },
    BUTTON_MULTIVALUE_HOVER_COLOR = {
        0.9,
        0.9,
        0.8
    },
    BUTTON_SELECT_COLOR = {
        1,
        1,
        1
    },
    BUTTON_MULTIVALUE_SELECT_COLOR = {
        1,
        1,
        0.9
    },
    BUTTON_READ_ONLY_COLOR = {
        0.6,
        0.6,
        0.6
    },
    BUTTON_MULTIVALUE_READ_ONLY_COLOR = {
        0.6,
        0.6,
        0.5
    },
    TEXT_INPUT_FOREGROUND_COLOR = {
        0.2,
        0.2,
        0.2
    },
    MENU_TITLE_SCALE = 0.75,
    MENU_FIELD_SCALE = 0.325,
    MENU_BUTTON_SCALE = 0.5,
    LEFT_MOUSE_BUTTON = 1,
    CARET_BLINK_INTERVAL = 0.5,
    CARET_WIDTH = 3,
    DISPLAY_FONT = nil,
    USER_INPUT_FONT = nil,
    LOGGER_NAME_BLACKLIST = {
        "client%-in%-[%p%d]+",
        "client%-out%-[%p%d]+",
        "connection%-dispatcher",
        "server%-in%-[%p%d]+",
        "server%-out%-[%p%d]+"
    },
    NOTIFICATION_DURATION = 2,
    NOTIFICATION_COLOR = {
        0.97,
        0.6,
        0.6
    },
    NOTIFICATION_PANEL_WIDTH = 1,
    NOTIFICATION_PANEL_HEIGHT = 1,
    NOTIFICATION_TEXT_SCALE = 0.5,
    NOTIFICATION_VSPACE = 30,
    NOTIFICATION_PADDING = 30,
    LOGO_COLOR_FG = {
        0.27,
        0.27,
        0.53,
        1.0
    },
    LOGO_COLOR_BG = {
        0.8,
        0.85,
        0.9,
        1.0
    },
    MENU_ENTRY_VSPACING = 20,
    MENU_TEXT_INPUT_WIDTH = 200,
    MENU_TEXT_INPUT_HEIGHT = 50,
    MENU_TEXT_INPUT_FIELD_MARGIN = 25,
    DRAW_AABBS_KEY = "f2",
    QUIT_KEY = "f4",
    TOGGLE_FULLSCREEN_KEY = "f11",
    BACKSTACK_KEY = "escape",
    PAGE_SELECT_BUTTON = 1,
    PAGE_DRAG_TOKEN_BUTTON = 2,
    PAGE_DRAG_VIEW_BUTTON = 3,
    PAGE_ZOOM_INCREASE = 1.3,
    PAGE_SELECTION_COLOR = {
        0,
        0.3,
        0.5,
        0.2
    },
    TOKEN_SELECTION_COLOR = {
        0,
        0.3,
        0.5,
        0.7
    },
    TOKEN_SELECTION_THICKNESS = 0.2,
    TOKEN_PANEL_PROPERTY_SCALE = 0.5,
    PADDING = 20,
    QUICK_ACCESS_PANEL_HEIGHT = 75.425
}

Consts.PANEL_FIELD_SCALE = Consts.MENU_FIELD_SCALE
Consts.PANEL_TEXT_INPUT_HEIGHT = Consts.MENU_TEXT_INPUT_HEIGHT

if config and config.window then
    Consts.DISPLAY_FONT = love.graphics.newFont("fonts/OpenSans.ttf", 80)
    Consts.USER_INPUT_FONT = love.graphics.newFont("fonts/NotoSansMono.ttf", 80)
end

return Consts
