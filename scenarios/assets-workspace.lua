local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

---@param driver ScenarioDriver
return function(driver)
    steps.join_game(driver)
    steps.open_assets_workspace(driver)
    driver:find("AssetListRow", "world/")
    local store = driver:server([[
        local paths = {}
        for _, entry in ipairs(app.games:get("meadow"):get_store():list()) do
            table.insert(paths, entry.path)
        end
        return table.concat(paths, " ")
    ]])
    driver:expect(store == "token token/bilbo.png token/smaug.png world world/world.png", "the server's store is the fixture's: " .. store)
    driver:key(Consts.BACKSTACK_KEY)
    driver:wait_screen("GameScreen")
end
