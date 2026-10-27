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
---@field game_screen GameScreen Set once the game is entered
---@field previous_filesystem love.filesystem|nil

---@return GameData
function game_client.game_data()
    return {
        name = "G",
        players = {
            piotr = {
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
            },
            Q = {
                name = "Q",
                width = 10,
                pixel_per_meter = 50,
                image = "world/q.png",
                tokens = {}
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
            },
            Gollum = {
                name = "Gollum",
                diameter = 1,
                avatar = "token/g.png",
                position = {
                    0,
                    0
                }
            }
        }
    }
end

---@return GameData `game_client.game_data()` with a game master's group, an empty group, a player's own grants and a token property no token holds
function game_client.entries_game_data()
    local data = game_client.game_data()
    data.groups.master = {
        title = "Game master",
        permissions = {
            "read",
            "write"
        }
    }
    data.groups.guest = {
        title = "Guest",
        permissions = {}
    }
    data.groups.player.permissions = {
        "read",
        "write:tokens/@owned"
    }
    data.players.adam = {
        group = "master"
    }
    data.players.piotr.permissions = {
        "view:tokens/Smaug"
    }
    data.token_properties.hp = {
        title = "HP",
        type = "number"
    }
    return data
end

---@param connection Connection
---@param id string The remote procedure's class name
---@return RequestBody
local function _pop_request(connection, id)
    local out_channel = connection:get_out_channel()
    while true do
        local payload = out_channel:pop() --[[@as string|nil]]
        assert(payload, "the client sent no " .. id .. " request")
        local request = table.from_string(love.data.decompress("string", Consts.NETWORK_COMPRESSION, payload) --[[@as string]] ) --[[@as Request]]
        if request.id == id then
            return request.body
        end
    end
end

---@param client AppMock
---@param connection Connection
---@param id string The remote procedure's class name
---@param body ResponseBody
local function _answer(client, connection, id, body)
    ---@type Response
    local response = {
        source = "c",
        id = id,
        body = body
    }
    connection:get_in_channel():push(love.data.compress("string", Consts.NETWORK_COMPRESSION, table.to_string(response)))
    app = client
    client.update_event:trigger(0.016)
end

---@param client AppMock
---@param user string
local function _answer_login(client, user)
    _answer(client, client.session:get_connection(), "LoginRp", {
        user = user
    })
end

---Logs `piotr` in, joins the game and enters it with `grants` as the permissions
---the server would have sent with the game's data
---@param grants string[]
---@param data GameData|nil Defaults to `game_client.game_data()`
---@return GameClient
function game_client.enter(grants, data)
    mocks.ensure_love_data()
    mocks.ensure_love_math()
    mocks.ensure_love_graphics()
    mocks.ensure_love_thread()
    local previous = mocks.install_love_filesystem({
        ["c/games/g/assets/world/w.png"] = "W",
        ["c/games/g/assets/token/b.png"] = "B",
        ["c/games/g/assets/token/s.png"] = "S",
        ["c/games/g/assets/token/g.png"] = "G",
        ["c/games/g/assets/world/q.png"] = "Q"
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
        local session = Session(connection):attach_lifetime(connection)
        client.session = session
        session:show_login()
    end
    ---@diagnostic disable-next-line: invisible
    client.connection_manager._on_disconnect = function()
        client.session = nil
        client.data = nil
    end
    client.connection_manager:add_connection(mocks.make_channel(), mocks.make_channel())
    local session = assert(client.session)
    local connection = session:get_connection()
    session:login("piotr", "")
    _pop_request(connection, "LoginRp")
    _answer_login(client, "piotr")
    assert(session:is_logged_in(), "the login answer logged the session in")
    assert(get_class_name_of(client.screen_manager:get_screen()) == "UserMenuScreen", "a login lands on the menu")
    session:join_game(mocks.GAME_ID)
    _pop_request(connection, "GameDataRp")
    _answer(client, connection, "GameDataRp", {
        success = true,
        game = mocks.GAME_ID,
        data = data or game_client.game_data(),
        permissions = grants
    })
    _pop_request(connection, "DownloadMissingAssetsRp")
    _answer(client, connection, "DownloadMissingAssetsRp", {
        success = true,
        contents = {}
    })
    local game_screen = client.screen_manager:get_screen() --[[@as GameScreen]]
    assert(get_class_name_of(game_screen) == "GameScreen")
    return {
        app = client,
        connection = connection,
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
---@param id string The remote procedure's class name
---@return RequestBody
function game_client.pop_request(client, id)
    return _pop_request(client.connection, id)
end

---@param client GameClient
---@param id string The remote procedure's class name
---@param body ResponseBody
function game_client.answer(client, id, body)
    _answer(client.app, client.connection, id, body)
end

---@return AssetEntry[] A store of two folders and a file, as the server lists it
function game_client.asset_entries()
    return {
        {
            path = "notes.txt",
            type = "file",
            size = 5
        },
        {
            path = "token",
            type = "directory"
        },
        {
            path = "token/b.png",
            type = "file",
            size = 1
        },
        {
            path = "token/s.png",
            type = "file",
            size = 1
        },
        {
            path = "world",
            type = "directory"
        },
        {
            path = "world/w.png",
            type = "file",
            size = 1
        }
    }
end

---@param client GameClient
---@param entries AssetEntry[]|nil Defaults to `game_client.asset_entries()`
---@param writable boolean|nil Defaults to `true`
---@return AssetsWorkspaceScreen
function game_client.open_workspace(client, entries, writable)
    app = client.app
    client.session:open_assets_workspace()
    local screen = client.app.screen_manager:get_screen() --[[@as AssetsWorkspaceScreen]]
    assert(get_class_name_of(screen) == "AssetsWorkspaceScreen")
    game_client.pop_request(client, "ListAssetsRp")
    game_client.answer(client, "ListAssetsRp", {
        success = true,
        entries = entries or game_client.asset_entries(),
        writable = writable ~= false
    })
    return screen
end

---@param client GameClient
---@param ctrl Control
function game_client.click(client, ctrl)
    app = client.app
    local min_x, min_y, max_x, max_y = ctrl:get_global_aabb():get_bounds()
    local x, y = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    local manager = client.app.button_event_manager
    manager:dispatch_pointer_move(x, y, 1)
    manager:dispatch_pointer_down(x, y, 1)
    manager:dispatch_pointer_up(x, y, 1)
end

---@param client GameClient
---@param ids string[] Ids of the tokens to select
function game_client.select(client, ids)
    local page = client.game_screen:get_page()
    local selection = page:get_selection()
    selection:unselect()
    ---@type table<string, boolean>
    local selected = {}
    for _, id in ipairs(ids) do
        selected[id] = true
    end
    for _, token in ipairs(page:get_tokens()) do
        if selected[token:get_id()] then
            local x, y = token:get_position()
            selection:set_start_point(x, y)
            selection:set_end_point(x, y)
            selection:add_apply()
            selection:hide()
        end
    end
end

---@param client GameClient
---@param id string A token's id
---@return Token
function game_client.find_token(client, id)
    for _, token in ipairs(client.game_screen:get_page():get_tokens()) do
        if token:get_id() == id then
            return token
        end
    end
    error("no token " .. id)
end

---@class GameClientEntrySend What the session was asked to send
---@field method "update_entry"|"create_entry"|"delete_entry"
---@field kind EntryKind
---@field id string
---@field changes table<string, EntryValue>|nil
---@field new_id string|nil
---@field entry EntryData|nil

---@param client GameClient
---@return GameClientEntrySend[] Filled as the session's `update_entry`, `create_entry` and `delete_entry` are called, which then send nothing
function game_client.record_entry_sends(client)
    ---@type GameClientEntrySend[]
    local sent = {}
    local session = client.session
    ---@param kind EntryKind
    ---@param id string
    ---@param changes table<string, EntryValue>
    ---@param new_id string|nil
    session.update_entry = function(_, kind, id, changes, new_id)
        table.insert(sent, {
            method = "update_entry",
            kind = kind,
            id = id,
            changes = changes,
            new_id = new_id
        })
    end
    ---@param kind EntryKind
    ---@param id string
    ---@param entry EntryData
    session.create_entry = function(_, kind, id, entry)
        table.insert(sent, {
            method = "create_entry",
            kind = kind,
            id = id,
            entry = entry
        })
    end
    ---@param kind EntryKind
    ---@param id string
    session.delete_entry = function(_, kind, id)
        table.insert(sent, {
            method = "delete_entry",
            kind = kind,
            id = id
        })
    end
    return sent
end

---@param client GameClient
---@return number x Where a side panel sits in the game screen
---@return number width
---@return number height
function game_client.side_panel_place(client)
    local w, h = assert(client.app.width), assert(client.app.height)
    local panel_w = w * Consts.GAME_SIDE_PANEL_SHARE
    return w - panel_w, panel_w, h
end

---@param client GameClient
---@return string[] The notifications since the last call
function game_client.take_notifications(client)
    local notifications = client.app.notification_manager --[[@as TestGameNotificationManager]]
    local messages = notifications.messages
    notifications.messages = {}
    return messages
end

return game_client
