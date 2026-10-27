local steps = require("scenarios.lib.steps")
local Utils = require("utils.utils")

local PAGE = "Cellar"
local PAGE_IMAGE = "world/world.png"
local GRANT = "write:tokens"
local PROPERTY = "hp"
local GROUP_TITLE = "Players"
local CREATE_REFUSAL = "Not allowed to create a page"

local SAVE = [[
    return assert(table.from_string(assert(love.filesystem.read("s/games/meadow/save.lua"))))
]]

local BOB_WAITS_FOR_THE_PAGE = [[
    local name = %q
    driver:wait_for(function()
        local screen = app.session:get_game_screen()
        return screen and screen:get_page():get_data().name == name
    end, nil, "bob's game screen showing " .. name)
    return require("utils.utils").get_time()
]]

local BOB_WAITS_FOR_THE_GRANT = [[
    driver:wait_for(function()
        return app.session:get_permissions():allows("write", "tokens")
    end, nil, "bob's session granted write on the tokens")
    local granted = require("utils.utils").get_time()
    driver:wait_for(function()
        local button = driver:try_find("TextButton", "New Token")
        return button and not button:is_read_only() and button
    end, nil, "bob's New Token entry writable")
    return granted
]]

local BOB_IS_REFUSED = [[
    app.session:create_entry("pages", "X", {name = "X", width = 1, pixel_per_meter = 1, image = "world/world.png"})
    driver:wait_for(function()
        return driver:try_find("Text", %q)
    end, nil, "the creation's refusal")
    driver:expect(app.data.pages.X == nil, "no page X in bob's data")
]]

---@param driver ScenarioDriver
---@return GameData
local function _read_save(driver)
    return assert(table.from_string("return " .. driver:server(SAVE))) --[[@as GameData]]
end

---@param panel GamePanel
---@param id string
---@return TextButton
local function _page_button(panel, id)
    for _, button in ipairs(panel:get_buttons()) do
        if button:get_text() == id then
            return button
        end
    end
    error("the game panel lists no page " .. id)
end

---@param driver ScenarioDriver
---@param page string
---@return number The time the lead's game screen showed the page
---@return number The time bob's did
local function _show_page(driver, page)
    local game = assert(assert(app.session):get_game_screen())
    local panel = steps.open_panel(driver, "Game") --[[@as GamePanel]]
    local bob = driver:client("bob", string.format(BOB_WAITS_FOR_THE_PAGE, page))
    local clicked = Utils.get_time()
    driver:click(_page_button(panel, page))
    driver:wait_for(function()
        return game:get_page():get_data().name == page
    end, nil, "adam's game screen showing " .. page)
    local shown = Utils.get_time()
    local bob_shown = assert(tonumber(bob:wait()))
    driver:expect(_page_button(panel, page):is_active(), "the game panel marks " .. page .. " shown")
    driver:log(string.format("%s shown on adam's client %.1f ms after the click, on bob's %.1f ms after it", page, (shown - clicked) * 1000, (bob_shown - clicked) * 1000))
    return shown, bob_shown
end

---@param driver ScenarioDriver
---@param panel EntriesPanel
---@param texts {[1]: string, [2]: string}[] Field keys and what is typed in them, in order
local function _fill(driver, panel, texts)
    for _, pair in ipairs(texts) do
        steps.set_text(driver, assert(panel:get_field_input(pair[1]), "the field " .. pair[1]), pair[2])
    end
end

---@param driver ScenarioDriver
---@param panel EntriesPanel
---@param id string
local function _start_new(driver, panel, id)
    driver:click(assert(panel:get_new_button(), "a New button"))
    driver:wait_for(function()
        return panel:is_new()
    end, nil, "the new entry state")
    steps.set_text(driver, assert(panel:get_id_input()), id)
end

---@param driver ScenarioDriver
---@param panel EntriesPanel
---@param done fun(): boolean The server's answer applied
---@param what string
---@return number The milliseconds from the click on Apply to `done`
local function _apply(driver, panel, done, what)
    local clicked = Utils.get_time()
    driver:click(assert(panel:get_apply_button(), "an Apply button"))
    driver:wait_for(done, nil, what)
    return (Utils.get_time() - clicked) * 1000
end

---@param panel EntriesPanel
---@param id string
---@return boolean
local function _lists(panel, id)
    for _, button in ipairs(panel:get_list_buttons()) do
        if button:get_text() == id then
            return true
        end
    end
    return false
end

return {
    peers = {
        "bob"
    },
    ---@param driver ScenarioDriver
    run = function(driver)
        local bob = driver:client("bob", [[
            steps.join_game(driver, "piotr", "secret")
        ]])
        local game = steps.join_game(driver)
        bob:wait()
        local data = assert(app.data)

        local pages = steps.open_panel(driver, "Pages") --[[@as PagesPanel]]
        _start_new(driver, pages, PAGE)
        _fill(driver, pages, {
            {
                "name",
                PAGE
            },
            {
                "width",
                "10"
            },
            {
                "pixel_per_meter",
                "4"
            }
        })
        driver:click(assert(pages:get_field_button("image"), "the image's Browse..."))
        driver:wait_screen("AssetsWorkspaceScreen")
        steps.pick_image(driver, PAGE_IMAGE)
        local image = assert(pages:get_field_input("image"))
        driver:expect(image:get_text() == PAGE_IMAGE, "the image field holds the pick: " .. image:get_text())
        local created = _apply(driver, pages, function()
            return data.pages[PAGE] ~= nil and _lists(pages, PAGE)
        end, "the page " .. PAGE .. " in adam's data and list")
        driver:log(string.format("the page %s created and listed %.1f ms after the click on Apply", PAGE, created))
        driver:expect(pages:get_selected() == PAGE, "the created page selected: " .. tostring(pages:get_selected()))
        local saved = _read_save(driver).pages[PAGE]
        driver:expect(saved and saved.name == PAGE and saved.width == 10 and saved.pixel_per_meter == 4 and saved.image == PAGE_IMAGE and #saved.tokens == 0,
                      "the page in the server's save: " .. table.to_string(saved))

        _show_page(driver, PAGE)
        driver:expect(#game:get_page():get_tokens() == 0, "the new page holds no token")
        local save = _read_save(driver)
        driver:expect(save.game.page == PAGE, "the save shows " .. PAGE .. ": " .. save.game.page)

        local players = steps.open_panel(driver, "Permissions") --[[@as PermissionsPanel]]
        steps.select_entry(driver, players, "piotr")
        _fill(driver, players, {
            {
                "permissions",
                GRANT
            }
        })
        local watch = driver:client("bob", BOB_WAITS_FOR_THE_GRANT)
        local clicked = Utils.get_time()
        driver:click(assert(players:get_apply_button(), "an Apply button"))
        local granted = assert(tonumber(watch:wait()))
        driver:log(string.format("bob's session granted %s %.1f ms after the click on Apply", GRANT, (granted - clicked) * 1000))
        local grants = _read_save(driver).players.piotr.permissions or {}
        driver:expect(#grants == 1 and grants[1] == GRANT, "piotr's grants in the save: " .. table.concat(grants, ", "))

        local properties = steps.open_panel(driver, "Token Properties") --[[@as TokenPropertiesPanel]]
        _start_new(driver, properties, PROPERTY)
        _fill(driver, properties, {
            {
                "title",
                "HP"
            },
            {
                "type",
                "number"
            }
        })
        local property_ms = _apply(driver, properties, function()
            return data.token_properties[PROPERTY] ~= nil and _lists(properties, PROPERTY)
        end, "the property " .. PROPERTY .. " in adam's data and list")
        driver:log(string.format("the token property %s created %.1f ms after the click on Apply", PROPERTY, property_ms))
        local property = _read_save(driver).token_properties[PROPERTY]
        driver:expect(property and property.title == "HP" and property.type == "number", "the property in the save: " .. table.to_string(property))

        local groups = steps.open_panel(driver, "Groups") --[[@as GroupsPanel]]
        steps.select_entry(driver, groups, "player")
        _fill(driver, groups, {
            {
                "title",
                GROUP_TITLE
            }
        })
        local group_ms = _apply(driver, groups, function()
            return data.groups.player.title == GROUP_TITLE
        end, "the group's new title in adam's data")
        driver:log(string.format("the group player retitled %.1f ms after the click on Apply", group_ms))
        local group = _read_save(driver).groups.player
        driver:expect(group.title == GROUP_TITLE, "the group's title in the save: " .. group.title)
        driver:expect(assert(groups:get_field_input("title")):get_text() == GROUP_TITLE, "the field refilled from the answer")

        _show_page(driver, "Meadow")
        driver:expect(#game:get_page():get_tokens() == 2, "Meadow's tokens on adam's page again: " .. #game:get_page():get_tokens())
        driver:expect(_read_save(driver).game.page == "Meadow", "the save shows Meadow again")

        driver:client("bob", string.format(BOB_IS_REFUSED, CREATE_REFUSAL)):wait()
        driver:expect(_read_save(driver).pages.X == nil, "no page X in the server's save")
    end
}
