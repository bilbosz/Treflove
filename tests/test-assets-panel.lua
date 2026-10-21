local test = require("tests.lib.test")
local game_client = require("tests.lib.game-client")

---@param client GameClient
---@return AssetsPanel
local function assets_panel(client)
    ---@diagnostic disable-next-line: invisible
    return client.game_screen._assets_panel
end

---@param grants string[]
---@param fn fun(panel: AssetsPanel)
local function with_panel(grants, fn)
    local client = game_client.enter(grants)
    ---@type boolean, any
    local ok, err = pcall(fn, assets_panel(client))
    game_client.finish(client)
    if not ok then
        error(err, 0)
    end
end

test.suite("AssetsPanel")

test.case("without write on the assets there is no Upload button, and a resize does without it", function()
    with_panel({
        "read",
        "write:tokens"
    }, function(panel)
        test.assert_eq(panel._upload_button, nil)
        test.assert_true(panel._cancel_button ~= nil, "a Cancel button")
        panel:on_resize(300, 900)
    end)
end)

test.case("with write on the assets there is an Upload button", function()
    with_panel({
        "read",
        "write:assets"
    }, function(panel)
        test.assert_true(panel._upload_button ~= nil)
        test.assert_true(panel._cancel_button ~= nil)
    end)
end)
