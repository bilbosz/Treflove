---@class Consts
local Consts = {
    APP_USAGE_MESSAGE = [[
Usage:
    love . <client|server> <address> <port> [options]
    love . console <address> <port> [chunk] [--follow] [--watch <expr>]
    love . monitor <address> <name>:<port>[,<name>:<port>...] [--console <port>] [--headless]
Options:
    --scenario <name>        client only: run scenarios/<name>.lua at start
    --console <port>         client, server and monitor: the console port on 127.0.0.1
    --server-console <port>  client only: the server's console port, for the scenario's server calls
    --identity <name>        client and server: the LÖVE save directory identity
    --fixture <path>         server only: a directory of the source tree that seeds the server root at load
    --headless               client, server and monitor: fixed frame delta, no sleep, no vsync
    --peers <name>:<port>,.. client only: the console ports of the peer clients a scenario drives
Console:
    chunk                    the Lua chunk to evaluate on the console at <address>:<port>; stdin until its end without one, or for "-"
    --follow                 after the reply, print every watch and log frame until the connection closes
    --watch <expr>           watch the expression under its own text and follow; no chunk with it
    exit code                0 for a result, 1 for an error, 2 for a usage or connection failure or an interrupt (Ctrl-C)
Monitor:
    <name>:<port>,..         the console ports at <address> to watch, each under its name
]],
    APP_SUCCESS_EXIT_CODE = 0,
    NETWORK_COMPRESSION = "lz4",
    NETWORK_PEER_LIMIT = 64,
    NETWORK_SERVICE_TIMEOUT_MS = 5,
    NETWORK_CONNECT_TIMEOUT_MS = 5000,
    NETWORK_DISCONNECT_TIMEOUT_MS = 1000,
    NETWORK_PEER_TIMEOUT_MS = 10000,
    SCENARIO_DIRECTORY = "scenarios",
    SCENARIO_WAIT_TIMEOUT = 10,
    SCENARIO_FAILURE_EXIT_CODE = 1,
    HASH_ALGORITHM = "sha256",
    SERVER_ROOT = "s",
    CLIENT_ROOT = "c",
    SERVER_SEED_DIRECTORY = "server/seed",
    GAME_TEMPLATE_DIRECTORY = "server/template",
    ACCOUNT_LOGIN_MAX_LENGTH = 32,
    ACCOUNT_NAME_MAX_LENGTH = 64,
    GAME_NAME_MAX_LENGTH = 64,
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
    LOGGER_NAME_BLACKLIST = {
        "client%-host",
        "server%-host"
    },
    TOGGLE_WATCH_OVERLAY_KEY = "f3",
    WATCH_OVERLAY_TEXT_SCALE = 0.35,
    WATCH_OVERLAY_PADDING = 20,
    WATCH_OVERLAY_MAX_LINE_LENGTH = 120,
    WATCH_OVERLAY_BACKGROUND_COLOR = {
        0,
        0,
        0,
        0.6
    },
    MONITOR_RECONNECT_SECONDS = 2,
    MONITOR_LOG_LINES = 500,
    MONITOR_MAX_LINE_LENGTH = 300,
    MONITOR_TEXT_SCALE = 0.3,
    MONITOR_TARGET_SCALE = 0.4,
    MONITOR_INPUT_HEIGHT = 50,
    MONITOR_SCROLL_LINES = 3,
    MONITOR_WATCH_PREFIX = "=",
    MONITOR_REPLY_PREFIX = "> ",
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
    PAGE_MAX_UNITS_PER_METER = 200,
    PAGE_MIN_VISIBLE = 50,
    PAGE_SURROUNDINGS_BLUR_GROWTH = 1,
    PAGE_SURROUNDINGS_BLUR_LIMIT = math.huge,
    PAGE_SURROUNDINGS_BLUR_BRIGHTNESS = 0.95,
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
    SCROLL_VIEW_DRAG_BUTTON = 3,
    SCROLL_VIEW_INDICATOR_LENGTH = 60,
    SCROLL_VIEW_INDICATOR_THICKNESS = 6,
    SCROLL_VIEW_INDICATOR_MARGIN = 4,
    SCROLL_VIEW_INDICATOR_COLOR = {
        0.8,
        0.85,
        0.9,
        0.6
    },
    TOKEN_PANEL_PROPERTY_SCALE = 0.5,
    PADDING = 20,
    QUICK_ACCESS_PANEL_HEIGHT = 75.425,
    ASSET_LIST_ROW_NORMAL_COLOR = {
        0,
        0,
        0,
        0
    },
    ASSET_LIST_ROW_HOVER_COLOR = {
        0.5,
        0.55,
        0.55
    },
    ASSET_LIST_ROW_SELECTED_COLOR = {
        0.3,
        0.35,
        0.4
    },
    ASSET_LIST_SCROLL_ROWS = 3,
    ASSETS_WORKSPACE_LIST_SHARE = 0.4,
    ASSETS_WORKSPACE_DETAILS_SHARE = 0.35,
    ASSETS_WORKSPACE_PREVIEW_SHARE = 0.45,
    FONT_PREVIEW_TEXT = "The quick brown fox jumps over the lazy dog",
    FONT_PREVIEW_SAMPLE_SCALE = 0.6,
    MEDIA_PLAYER_TRACK_COLOR = {
        0.8,
        0.85,
        0.9,
        0.25
    }
}

Consts.PANEL_FIELD_SCALE = Consts.MENU_FIELD_SCALE
Consts.PANEL_TEXT_INPUT_HEIGHT = Consts.MENU_TEXT_INPUT_HEIGHT

return Consts
