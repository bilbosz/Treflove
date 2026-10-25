local test = require("tests.lib.test")
local asset_usage = require("data.asset-usage")

---@return GameData
local function game_data()
    return {
        game = {
            page = "P"
        },
        groups = {},
        players = {},
        pages = {
            P = {
                name = "P",
                width = 10,
                pixel_per_meter = 50,
                image = "world/w.png",
                tokens = {
                    "T"
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
            avatar = {
                title = "Avatar",
                type = "image"
            },
            badge = {
                title = "Badge",
                type = "image"
            }
        },
        tokens = {
            T = {
                name = "T",
                diameter = 3,
                avatar = "token/t.png",
                badge = "token/star.png",
                position = {
                    1,
                    2
                }
            },
            U = {
                name = "token/t.png",
                diameter = 2,
                avatar = "token/u.png",
                position = {
                    3,
                    4
                }
            }
        }
    }
end

test.suite("asset_usage")

test.case("what refers to an asset: the pages by their image, the tokens by their image properties, in name order", function()
    local data = game_data()
    test.assert_deep_eq(asset_usage.find(data, "token/t.png"), {
        {
            kind = "token",
            name = "T",
            key = "avatar"
        }
    }, "a string property that is not an image does not count")
    test.assert_deep_eq(asset_usage.find(data, "world/w.png"), {
        {
            kind = "page",
            name = "P"
        }
    })
    test.assert_deep_eq(asset_usage.find(data, "token/star.png"), {
        {
            kind = "token",
            name = "T",
            key = "badge"
        }
    })
    test.assert_deep_eq(asset_usage.find(data, "token/x.png"), {})
end)

test.case("a folder is referred to by everything under it", function()
    local data = game_data()
    test.assert_deep_eq(asset_usage.find(data, "token"), {
        {
            kind = "token",
            name = "T",
            key = "avatar"
        },
        {
            kind = "token",
            name = "T",
            key = "badge"
        },
        {
            kind = "token",
            name = "U",
            key = "avatar"
        }
    })
    test.assert_deep_eq(asset_usage.find(data, "world"), {
        {
            kind = "page",
            name = "P"
        },
        {
            kind = "page",
            name = "Q"
        }
    })
    test.assert_deep_eq(asset_usage.find(data, "tok"), {}, "a name prefix is not a folder")
end)

test.case("a use is described by its kind, its name and the property; it is on the shown page or not", function()
    local data = game_data()
    local page_p, page_q, token_t, token_u = {
        kind = "page",
        name = "P"
    }, {
        kind = "page",
        name = "Q"
    }, {
        kind = "token",
        name = "T",
        key = "badge"
    }, {
        kind = "token",
        name = "U",
        key = "avatar"
    }
    test.assert_eq(asset_usage.describe(page_p), "page \"P\"")
    test.assert_eq(asset_usage.describe(token_t), "token \"T\" (badge)")
    test.assert_true(asset_usage.is_on_shown_page(data, page_p))
    test.assert_false(asset_usage.is_on_shown_page(data, page_q))
    test.assert_true(asset_usage.is_on_shown_page(data, token_t))
    test.assert_false(asset_usage.is_on_shown_page(data, token_u), "on no page")
    data.game = nil
    test.assert_false(asset_usage.is_on_shown_page(data, page_p), "no page is shown")
end)

test.case("a renamed asset is followed by its references, a renamed folder by everything under it", function()
    local data = game_data()
    asset_usage.rename(data, "world/w.png", "maps/old-town.png")
    test.assert_eq(data.pages.P.image, "maps/old-town.png")
    test.assert_eq(data.pages.Q.image, "world/q.png")

    asset_usage.rename(data, "token", "people")
    test.assert_eq(data.tokens.T.avatar, "people/t.png")
    test.assert_eq(data.tokens.T.badge, "people/star.png")
    test.assert_eq(data.tokens.U.avatar, "people/u.png")
    test.assert_eq(data.tokens.U.name, "token/t.png", "a string property keeps its text")
end)
