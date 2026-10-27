local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

local GAME = "Old Town"

---@type string[]
local TOKENS = {
    "Bilbosz",
    "Gaben",
    "Bilbosza Wielka",
    "Anonim"
}

local SERVER_STORE = [[
    local paths = {}
    for _, entry in ipairs(app.games:get("old-town"):get_store():list()) do
        table.insert(paths, entry.path)
    end
    return table.concat(paths, " ")
]]

local FIXTURE_STORE = "token token/bilbosz.png token/bilbosza.png token/default.png token/gaben.png world world/world.jpg"

return {
    fixture = "old-town",
    ---@param driver ScenarioDriver
    run = function(driver)
        local game = steps.join_game(driver, nil, nil, GAME)
        local page = game:get_page()
        local name = page:get_data().name
        driver:expect(name == GAME, "the fixture's page is shown: " .. name)
        for _, token in ipairs(TOKENS) do
            driver:find("Token", token)
        end
        local tokens = #page:get_tokens()
        driver:expect(tokens == #TOKENS, "the page holds the fixture's four tokens: " .. tokens)
        local root = app.asset_manager:get_store():get_root()
        driver:expect(root == "c/games/old-town", "the client keeps the game's assets in a store of its own: " .. root)

        steps.open_assets_workspace(driver)
        driver:find("AssetListRow", "world/")
        local store = driver:server(SERVER_STORE)
        driver:expect(store == FIXTURE_STORE, "the server's store is the fixture's: " .. store)
        driver:key(Consts.BACKSTACK_KEY)
        driver:wait_screen("GameScreen")
        driver:log("screenshot " .. driver:screenshot("old-town.png"))
    end
}
