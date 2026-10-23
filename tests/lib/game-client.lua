local mocks = require("tests.lib.mocks")
local lifetime = require("lifetime")
local AssetManager = require("data.asset-manager")
local Consts = require("app.consts")
local Control = require("controls.control")
local Session = require("game.session")
local ConnectionManager = require("networking.connection-manager")
local ScreenManager = require("screens.screen-manager")
local ButtonEventManager = require("ui.button-event")
local TextEventManager = require("ui.text-event")
local BackstackManager = require("utils.backstack-manager")

---A client in the game with no server behind it: the login answered on the
---wire, the game data and the grants set by the case
---@class game_client
local game_client = {}

---@class TestGameNotificationManager: NotificationManager
---@field messages string[]
local TestGameNotificationManager = class("TestGameNotificationManager")

function TestGameNotificationManager:init()
    self.messages = {}
end

---@param message string
function TestGameNotificationManager:notify(message)
    table.insert(self.messages, message)
end

---@class GameClient
---@field app AppMock
---@field connection Connection
---@field session Session
---@field game_screen GameScreen
---@field previous_filesystem love.filesystem|nil

---@return GameData
function game_client.game_data()
    return {
        players = {
            piotr = {
                name = "Piotrek",
                group = "player"
            }
        },
        groups = {
            player = {
                title = "Player",
                permissions = {
                    "read"
                }
            }
        },
        game = {
            page = "P"
        },
        pages = {
            P = {
                name = "P",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "Bilbosza",
                    "Smaug"
                }
            }
        },
        token_properties = {
            name = {
                title = "Name",
                type = "string"
            },
            diameter = {
                title = "Diameter",
                type = "number"
            },
            avatar = {
                title = "Avatar",
                type = "image"
            },
            owners = {
                title = "Owners",
                type = "array"
            },
            position = {
                title = "Position",
                type = "array"
            }
        },
        tokens = {
            Bilbosza = {
                name = "Bilbosza Wielka",
                diameter = 1,
                avatar = "token/b.png",
                owners = {
                    "piotr"
                },
                position = {
                    2,
                    2
                }
            },
            Smaug = {
                name = "Smaug",
                diameter = 1,
                avatar = "token/s.png",
                position = {
                    4,
                    2
                }
            }
        }
    }
end

---@param client AppMock
---@param user string
local function _answer_login(client, user)
    ---@type Response
    local response = {
        source = "c",
        id = "LoginRp",
        body = {
            user = user
        }
    }
    local in_channel = client.session:get_connection():get_in_channel()
    in_channel:push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(response)))
    client.update_event:trigger(0.016)
end

---Logs `piotr` in and enters the game with `grants` as the permissions
---the server would have sent with `game_client.game_data()`
---@param grants string[]
---@return GameClient
function game_client.enter(grants)
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    mocks.ensure_love_thread()
    local previous = mocks.install_love_filesystem({
        ["c/assets/world/w.png"] = "W",
        ["c/assets/token/b.png"] = "B",
        ["c/assets/token/s.png"] = "S"
    })
    local client = mocks.install_app()
    client.root = Control()
    client.width, client.height = 2000, 1500
    client.screen_manager = ScreenManager()
    client.backstack_manager = BackstackManager()
    client.button_event_manager = ButtonEventManager()
    client.text_event_manager = TextEventManager(mocks.make_keyboard())
    client.notification_manager = TestGameNotificationManager()
    client.asset_manager = AssetManager()
    client.connection_manager = ConnectionManager("localhost", "8080")
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_connect = function(connection)
        client.session = Session(connection):attach_lifetime(connection)
    end
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_disconnect = function()
        client.session = nil
        client.data = nil
    end
    client.connection_manager:add_connection(mocks.make_channel(), mocks.make_channel())
    local session = assert(client.session)
    _answer_login(client, "piotr")
    assert(session:is_logged_in(), "the login answer logged the session in")
    client.data = game_client.game_data()
    session:set_grants(grants)
    session:enter_game()
    local game_screen = client.screen_manager:get_screen() --[[@as GameScreen]]
    assert(get_class_name_of(game_screen) == "GameScreen")
    return {
        app = client,
        connection = session:get_connection(),
        session = session,
        game_screen = game_screen,
        previous_filesystem = previous
    }
end

---Disconnects, which destroys the session with its game screen: no form is
---left to the collector (docs/lifetimes.md, "Forms and inputs")
---@param client GameClient
function game_client.finish(client)
    app = client.app
    client.app.connection_manager:remove_all()
    assert(not lifetime.alive(client.game_screen))
    mocks.restore_love_filesystem(client.previous_filesystem)
end

---@param client GameClient
---@param keys string[] Keys of `GameData.tokens`, the tokens to select
function game_client.select(client, keys)
    local page = client.game_screen:get_page()
    local selection = page:get_selection()
    selection:unselect()
    ---@type table<string, boolean>
    local selected = {}
    for _, key in ipairs(keys) do
        selected[key] = true
    end
    for _, token in ipairs(page:get_tokens()) do
        if selected[token:get_key()] then
            local x, y = token:get_position()
            selection:set_start_point(x, y)
            selection:set_end_point(x, y)
            selection:add_apply()
            selection:hide()
        end
    end
end

---@param client GameClient
---@param key string A key of `GameData.tokens`
---@return Token
function game_client.find_token(client, key)
    for _, token in ipairs(client.game_screen:get_page():get_tokens()) do
        if token:get_key() == key then
            return token
        end
    end
    error("no token " .. key)
end

return game_client
