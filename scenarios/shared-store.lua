local Consts = require("app.consts")
local steps = require("scenarios.lib.steps")

local FOLDER = "shared"

return {
    peers = {
        "bob"
    },
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", [[
            steps.join_game(driver, "piotr", "secret")
        ]])
        steps.join_game(driver)
        bob:wait()

        steps.open_assets_workspace(driver)
        driver:click("TextInput", nil, 1)
        driver:type(FOLDER)
        driver:click("TextButton", "New Folder")
        driver:wait_for(function()
            return driver:try_find("AssetListRow", FOLDER .. "/")
        end, nil, "the new folder in the lead's listing")

        driver:client("bob", string.format([[
            steps.open_assets_workspace(driver)
            driver:find("AssetListRow", %q)
        ]], FOLDER .. "/")):wait()
        local kind = driver:server(string.format([[
            return app.games:get("meadow"):get_store():asset(%q):get_type()
        ]], FOLDER))
        driver:expect(kind == "directory", "the folder is in the game's store on the server: " .. kind)

        driver:key(Consts.BACKSTACK_KEY)
        driver:wait_screen("GameScreen")
    end
}
